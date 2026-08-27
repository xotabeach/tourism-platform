# Full project review — Crimea Travel Platform

**Дата:** 2026-08-27  
**Режим:** независимое read-only ревью всего workspace  
**Автор:** Cursor (Grok 4.6), с параллельными субагентами backend / mobile / security / product-docs  
**Код не менялся.** Production, deploy, push и stash не трогались.

Связанный backlog: [2026-08-27-review-remediation-plan.md](2026-08-27-review-remediation-plan.md).

Предыдущие ревью (перепроверены, не скопированы):

- [2026-08-25-backend-architecture-ai-review.md](2026-08-25-backend-architecture-ai-review.md) (`tourism-backend` @ `4fb9a11`)
- [2026-08-25-mobile-code-security-perf-review.md](2026-08-25-mobile-code-security-perf-review.md) (`tourism-mobile` @ `2e12d64`)
- [2026-08-25-mobile-ux-review.md](2026-08-25-mobile-ux-review.md)
- [2026-08-25-review-remediation-plan.md](2026-08-25-review-remediation-plan.md) — фазы 0–6 смержены в `main`; 7–8 не начаты

---

## Executive summary

CrimeaTrip — **рабочий test-contour продукт**, не skeleton. Auth (OTP/JWT), каталог published-мест и маршрутов, избранное, отзывы, профиль/тп/лидерборд, SQLAdmin, form-match, generate и Travel+-gated AI-чат **реально существуют в коде**. Фазы ремедиации 0–6 от 2026-08-25 **подтверждены закрытыми** на текущем `main`.

Это всё ещё **не приложение, на которое турист опирается в Крыму**. Каталог показывает только `publication_status=published`; машинный гейт 2026-08-24 насчитал **141 готовое место** при тысячах OSM-drafts (700 без города). Расстояния — haversine × 1.35, не дороги. «Пройти маршрут» — snackbar. Свайп-колода не имеет backend-рекомендаций. Предпочтения сохраняются и **не влияют** на подбор. На публичном хосте Travel+ нельзя выдать себе через mock checkout — AI-чат требует admin grant.

**P0 (security / data-loss / release blocker) на корректно сконфигурированном `APP_ENV=production` не подтверждены.**

Главные риски ближайшего релиза:

1. Support-фото (и любой объект под `/media`) отдаются **без auth** (`StaticFiles`).
2. SQLAdmin висит на том же публичном Caddy vhost, без MFA и без IP-allowlist.
3. Ранг «Эксперт» (коммит `432df1c`) согласован в профиле/лидерборде и **расходится** на карточках маршрутов и в отзывах.
4. AI-ход держит DB-сессию до 60 с, а Dio на клиенте обрывается через **20 с**.
5. Документация всё ещё называет живые `route_builder` / `subscriptions` заглушками и держит три конфликтующие системы «фаз».

Сильная сторона: security-контур auth (rotation + `FOR UPDATE`, publication filters, Travel+ env-gate, LLM redaction, chat media allowlist) после 25 августа выглядит взрослым для размера команды. Слабая сторона: **данные + честность продукта + media delivery**, не FastAPI и не Riverpod.

Микросервисы, Kafka, Kubernetes, Gemini, Qdrant и новый AI-слой **не нужны** и вредны на этой стадии (ADR-001 / ADR-005 / ADR-009).

---

## Зафиксированные SHA

| Repository | Branch | SHA | Замечание |
| --- | --- | --- | --- |
| workspace | `main` | `bd91437a4be99d735a960c6ae3b4b892caae2a50` | чисто, = `origin/main` |
| tourism-backend | `main` | `80cdba144989754c7ee069d33cbbc5152e60bd0e` | `docs: update backend API README` (2026-08-27); Expert-ранг в `432df1c` |
| tourism-mobile | `main` | `e1b8fbbb5089c08d272651ad5d2eded4ca15767c` | `feat: finish mobile navigation and test coverage` (2026-08-27) |
| tourism-platform | `main` | `6343cd07ea5753aea8b0f53c0fed7c1b91d3a01a` | `docs: sync status with latest feature changes` |

Незакоммиченных изменений не было. Stash mobile `stash@{0}` (`wip aside for phase 2-4 branches`) **не трогался**.  
`AGENTS.md` в workspace и сабмодулях **нет**; действуют `.cursor/rules/*.mdc`.

---

## Методика и ограничения

1. Прочитаны канонические docs (`progress`, `implementation-plan`, business logic, domain, stack, screens spec, route-intelligence, ADR, `docs/security/*`, прошлые reviews) и сверены с routers, миграциями `0001`–`0037`, Flutter routes и тестами.
2. Четыре независимых субагента + ручная перепроверка каждого P0/P1 родителем по текущему дереву.
3. Старые ID 2026-08-25 сначала искались в коде; закрытые помечены отдельно, открытые — с новыми file:line.
4. Запуски: platform `validate.sh`; backend `validate.sh` (ruff, mypy, pip-audit, полный pytest); mobile format/analyze/test/goldens **без записи** (`dart format --output=none`).
5. **Не запускалось:** DAST, Trivy, gitleaks binary, EXPLAIN/нагрузка, production SSH, чтение `.env` (файлы есть, значения не открывались), Firebase Console.

Ограничения: production load не измерялся; поведение Caddy XFF на живом хосте — hypothesis; точное число *задеплоенных* published places не запрашивалось у API.

---

## Оценка зрелости

| Направление | Балл /5 | Комментарий |
| --- | --- | --- |
| Продукт для туриста | 2.5 | Каталог/социальная оболочка есть; walk/offline/hours/дороги — нет или stub |
| Backend-архитектура | 4 | Modular monolith уместен; границы модулей бумажные (M-5) |
| Mobile-архитектура | 4 | Feature-first + Notifier чата; pagination/history ещё в `State` |
| Безопасность | 3.5 | Auth сильный; `/media` и `/admin` слабые; lean CI не ловит регресс |
| Производительность | 3 | Списки батчатся; AI держит пул; thumbs без decode cap |
| Тесты | 3.5 | Backend security сильный; mobile 269 зелёных при красном `validate.sh` |
| Документация | 2.5 | Объём высокий, SoT конфликтует (stubs / фазы / ADR-008) |
| Эксплуатация | 3 | Deploy-скрипты есть; backup/cron/observability dashboard — нет |

---

## Сильные стороны

- Hybrid auth по ADR-007: OTP SHA-256 + constant-time, refresh rotation + reuse detection + `FOR UPDATE`, JWT HS256 allowlist, access в RAM, refresh в Keychain/Keystore.
- Publication-инварианты на каталоге, обложках, избранном; unpublished stop прячет маршрут из public list.
- AI-граница после фазы 0/3: tool allowlist, redacted crisis/injection, GPU fail-fast, `protect_confirmed` на прямых ключах, `ST_DWithin`+`LIMIT` на geo-tool, SQL `LIMIT 12` истории.
- Uploads support/reviews: decode, allowlist, EXIF strip, WebP, pixel cap, `DecompressionBombError` (на support/review).
- Mobile: `Caching*` единственный production-конструктор каталогов; chat images через `AppImages.coverImage`; `RouteMatchNotifier` + behavioral-тесты; place/route twins сведены к shared reviews/audio/collapse/loading.
- Ошибка API — стабильный envelope, без отражения сырого ввода; `/health/ready` не утекает driver text.
- ADR-001/009 держат команду от преждевременного split и от «ещё одного эмбеддера» при пустых колонках.
- Линейная цепочка Alembic до `0037`; 0035–0037 совпадают с support photos / preferences / expert rank.

---

## Закрытые находки прошлых ревью (перепроверено 2026-08-27)

| ID | Статус | Доказательство |
| --- | --- | --- |
| M-1 mock Travel+ | закрыто | `subscriptions/presentation/router.py:25-30`, `entitlements.py:62-71` (`local`/`test` only) |
| M-2 cover publication | закрыто | `media/application/service.py:230-258`, `place_covers.py` |
| M-3 favorites publication | закрыто | `favorites/application/service.py:14-47,74-77` |
| M-4 refresh `FOR UPDATE` | закрыто | `identity/application/service.py:351-369` |
| AI-1 GPU slot | закрыто | `lm_studio.py:81-96,296-321` |
| AI-2 per-turn metrics | закрыто | `session_service.py:694-740` |
| AI-3 affirmatives | закрыто | `topic_guard.py:137-164` |
| AI-4 history redaction | закрыто | persist `[redacted]`; SQL omit |
| AI-5 quota lock | закрыто | `quota.py:44-58` |
| AI-6 confirmed keys | закрыто для прямых ключей; остаток `interests_add` = BE-2026-05 | `chat_actions.py:350-351` |
| AI-7 `ST_DWithin` | закрыто | `tool_registry.py:412-467` |
| AI-8 history LIMIT | закрыто | `session_service.py:96-133` |
| AI-9 outage fallback | закрыто | soft fallback, не сырой 500 |
| SEC-1 chat `Image.network` | закрыто | `lib/` — 0 вызовов; `chat_image_allowlist_test.dart` |
| CODE-1/2 refresh map | закрыто | `app_data_refresh.dart` инвалидирует `homePlacesProvider` / places на myRoutes |
| CODE-9/13/15 chat god-State + тесты | закрыто для пайплайна | `RouteMatchNotifier` + `route_match_notifier_test.dart` + Travel+ activate test |
| UX twins reviews/audio/loading | закрыто как унификация | `EntityReviewsSection`, `AudioGuideCard`, `HeroCollapseSpec`, `DetailsHeroLoadingView` |
| PERF-11/12/15 session watch | закрыто на hero/home/shell | `.select` |
| PERF-17 Firebase до `runApp` | закрыто | `main.dart:17-21` post-frame |
| July 2025 P1s (INTERNET, filters, raw Dio) | закрыто | as-built |

Всё ещё открыты с плана 25 августа: **M-5** (cross-ORM), **AI-11** (docs Gemini/Ollama — частично подчищено, README/stack всё ещё врут), mobile **Phase 7–8** (SearchScreen, a11y contract, cache keys, `file://`, token debt, EntityReviews hex).

---

## Findings, отсортированные по приоритету

Приоритет: **P0** — немедленный security/data-loss/release blocker; **P1** — серьёзный дефект ближайшего релиза; **P2** — долг / UX / perf; **P3** — улучшение.

**P0: 0.**  
Ниже — подтверждённые дефекты, затем отдельно идеи и гипотезы.

### P1

#### SEC-2026-02 — Support (и прочие) файлы на публичном `/media`

- **Категория:** security / media · **Репозиторий:** tourism-backend  
- **Доказательство:** `main.py:70-71` монтирует `StaticFiles` на `/media` без auth. Support пишет `public_path=/media/support/{ticket_id}/{uuid}.webp` (`support/application/attachments.py:78-87`). Owner check только на JSON API (`support/application/service.py:200-202`). Security-тест проверяет BOLA на POST, не GET файла.  
- **Сценарий:** URL из JSON приложения, скриншота или лога → любой `GET` без Bearer читает фото обращения.  
- **Impact:** конфиденциальные фото (устройство, баги). UUID снижает brute-force, это не access control.  
- **Исправление:** не класть `support/` (и pending reviews) на публичный mount; authenticated route или signed TTL URL. Каталожные обложки можно оставить публичными.  
- **Acceptance:** anonymous GET support object → 401/404; владелец/admin — 200; `/media/places/...` без изменений.  
- **Тест:** security: owner 200, stranger 404, anonymous 401/404.  
- **Зависимости:** mobile должен ходить в тот же URL shape или на новый.  
- **Confidence:** high · **Kind:** confirmed defect

#### SEC-2026-01 — SQLAdmin на публичном API-хосте без MFA

- **Категория:** security / admin · **Репозиторий:** tourism-backend + tourism-platform  
- **Доказательство:** `admin/presentation/setup.py:32-41` — `admin_enabled` default on; `https_only` cookie только staging/production, **не** `test`. `deploy/test/Caddyfile:6-18` reverse_proxy всех путей, без IP allowlist. User-brief отдаёт `phone_e164` (`setup.py:65-78`).  
- **Сценарий:** интернет-клиент открывает `/admin/login` на test/prod host; password spray по bootstrap-аккаунту. На `APP_ENV=test` cookie без `Secure`.  
- **Impact:** полный ops-доступ: пользователи, OTP debug (test), публикация, телефоны.  
- **Существующие защиты:** Argon2id, login rate limit, CSRF, SameSite=Lax, mobile JWT не открывает `/admin`.  
- **Исправление:** IP allowlist / отдельный host; MFA; `Secure` cookie на любом HTTPS contour; не показывать `debug_code` на сетевом контуре.  
- **Acceptance:** не-allowlisted клиент → 403/404 на `/admin`; cookie `Secure` при TLS.  
- **Тест:** request `/admin/login` с «чужой» сети; CSRF tests уже есть.  
- **Confidence:** high · **Kind:** confirmed (exposure); MFA absence confirmed

#### BE-2026-01 — `rank_title` на каталоге и в отзывах игнорирует «Эксперт»

- **Категория:** correctness · **Репозиторий:** tourism-backend  
- **Доказательство:** профиль: `public_service.py:35-46` (`is_expert` → `EXPERT_RANK_ID`). Каталог: `routes/application/service.py:182-204` — только `travel_points` vs все `TravelRank.min_points`. То же: `places/.../review_service.py:38-51`, `routes/.../review_service.py:61-77`. Expert `min_points = 1_000_000_000` (`0037_expert_travel_rank.py:27-30`). `test_expert_rank.py` не бьёт catalog/review; `test_route_author_rank.py` не кладёт expert-ряд.  
- **Сценарий:** admin выдаёт Эксперта; у пользователя 80 тп. Профиль — «Эксперт», карточка маршрута и byline отзыва — «Новичок». `author_is_expert` может быть true при чужом title.  
- **Impact:** инвариант `432df1c` сломан на самом видимом UI.  
- **Исправление:** один resolver: expert → title «Эксперт», иначе points среди non-expert ranks. Использовать в routes + обоих review services.  
- **Acceptance:** Expert с малыми тп → `author_rank_title="Эксперт"` на `GET /routes`, match, published reviews; revoke возвращает points-ранг.  
- **Тест:** unit `_rank_titles` с expert row 1e9; API public route владельца-эксперта.  
- **Confidence:** high · **Kind:** confirmed defect

#### BE-2026-03 — Planning `post_message` держит DB на время LM Studio; клиент рвёт через 20 с

- **Категория:** reliability / transactions · **Репозиторий:** tourism-backend + tourism-mobile  
- **Доказательство:** `_owned_session` — plain `session.get` без `FOR UPDATE` (`session_service.py:984-997`). User flush `:396-397`, затем HTTP до `ai_request_timeout_seconds=60` (`config.py:85`) на той же `AsyncSession`. Commit только около `:559`. Engine: `create_async_engine(..., pool_pre_ping=True)` без `pool_size` (`db/session.py:13-14`). Mobile: `receiveTimeout: 20s` (`api_client.dart:13-14,25-26`). GPU-слот сериализует inference, **не** checkout соединения.  
- **Сценарий:** двойной тап чата → last-write-wins по constraints; 2–3 чата занимают пул на минуту; клиент показывает ошибку на 20 с, пока GPU/DB ещё работают; retry усугубляет. Test compose: `mem_limit: 192m`, Postgres `max_connections=20`.  
- **Impact:** потеря состояния чата, stall каталога/`/health/ready`, ложный «AI сломан» у пользователя.  
- **Исправление:** `FOR UPDATE` на session row; commit user-turn **до** HTTP; отдельная короткая транзакция; явный pool; Dio timeout ≥ server (или наоборот, server ≤ 20 с) + отмена при disconnect.  
- **Acceptance:** concurrent POST сериализуется (или 409); `/health/ready` и `GET /places` живы при N чатах; клиент не рвёт раньше сервера.  
- **Тест:** concurrent `post_message`; интеграция fake 2s provider + 8 chats + 8 `/places`.  
- **Confidence:** high (механизм); production load не измерен · **Kind:** confirmed defect + architectural risk (pool)

#### MO-2026-19 — Гонка пагинации `AllListScreen` при смене режима

- **Категория:** correctness · **Репозиторий:** tourism-mobile  
- **Доказательство:** `all_list_screen.dart:104-158`. `_loadNextPage` читает `_mode` до `await`, затем `addAll` без generation token. `_switchMode` стартует второй load; `finally` первого ставит `_loading=false` пока второй ещё идёт.  
- **Сценарий:** «Смотреть все» → скролл → быстро Маршруты↔Локации.  
- **Impact:** чужой тип в списке, сбитый offset, дубли.  
- **Исправление:** generation/`Object()` token; игнорировать stale; `_loading` пока *текущий* запрос жив.  
- **Acceptance:** быстрый toggle во время load не смешивает типы.  
- **Тест:** delayed fake repos; switch mid-flight; assert contents.  
- **Confidence:** high · **Kind:** confirmed defect

#### DOC-2026-01 — README/stack называют живые модули заглушками

- **Категория:** documentation · **Репозиторий:** workspace + backend + platform  
- **Доказательство:** workspace `README.md:47-49`; `tourism-backend/README.md:12-15`; `tourism-platform/README.md:16-18,30-33` («planning API ещё нет», stub `route_builder`). Код: `api/v1/router.py:24-30` включает `route_builder_router` и `subscriptions_router`.  
- **Сценарий:** новый разработчик пропускает ядро продукта или начинает «писать Phase 8A».  
- **Impact:** ложная карта проекта; дублирование работы.  
- **Исправление:** stub только `route_execution`. 8A/8B as-built + флаги.  
- **Acceptance:** grep «пакеты без router» / «planning API ещё нет» не матчит route_builder/subscriptions.  
- **Тест:** doc checklist / markdown grep в platform validate.  
- **Confidence:** high · **Kind:** documentation drift

#### DOC-2026-02 — Три системы «фаз» противоречат as-built

- **Категория:** documentation · **Репозиторий:** tourism-platform  
- **Доказательство:** `progress.md:7` — «Phase 8B in progress»; `:36` — «Next — фазы 7 и 8» (review-remediation); таблица `:994-1014` — 8A/8B **pending**, 5/6 **in_progress**. Implementation-plan всё ещё описывает 8A как будущую.  
- **Impact:** нельзя ответить «что сейчас делать».  
- **Исправление:** Product phase / Review-remediation (R0–R8) / Route-intelligence (P0–P4). 8A = done (stub routing); 8B = done-experimental (`ai_planning_enabled` default false).  
- **Acceptance:** одна таблица статусов совпадает с changelog и кодом.  
- **Confidence:** high · **Kind:** documentation drift

#### DOC-2026-03 / ARC-2026-01 — Два разных ADR-008

- **Категория:** architecture docs · **Репозиторий:** tourism-platform  
- **Доказательство:** `docs/decisions/ADR-008-ops-admin-sqladmin.md` и `ADR-008-rag-pgvector.md`. ADR-009 ссылается на ADR-008 как pgvector; implementation-plan Phase 6.5 — как SQLAdmin.  
- **Impact:** следующий ADR нельзя безопасно пронумеровать; поиск «ADR-008» двусмыслен.  
- **Исправление:** pgvector остаётся ADR-008; ops-admin → **ADR-010** со stub-redirect.  
- **Acceptance:** один файл `ADR-008-*`; все ссылки однозначны.  
- **Confidence:** high · **Kind:** documentation drift

#### ARC-2026-07 — Каталог мест на клиенте игнорирует серверные фильтры и пагинацию

- **Категория:** architecture / product · **Репозиторий:** tourism-mobile (+ backend API уже умеет)  
- **Доказательство:** `GET /places` принимает `q`, category, difficulty, children/pets/season. `placesListProvider` (`places_providers.dart:23-25`) зовёт `listPlaces(regionSlug: 'crimea')` без query; default Dart limit 50. Home chips — substring heuristics (`home_screen.dart:126-144`). All-list search подменяет список overlay (`all_list_screen.dart:200-230`), не `query` в `listPlaces`.  
- **Сценарий:** после публикации >50 (цель ADR-009 / 141 ready) чипы и «поиск» лгут.  
- **Impact:** data-first стратегия упирается в клиент, не в API.  
- **Исправление:** прокинуть query/filters/offset; чипы с таксономии, не `ялт`.  
- **Acceptance:** вторая страница и фильтр категории бьют API; `total` совпадает.  
- **Тест:** widget/repo test с `limit/offset/q`.  
- **Confidence:** high · **Kind:** confirmed defect (при росте каталога — сегодня маскируется размером published set)

---

### P2

#### BE-2026-05 — `protect_confirmed` не закрывает `interests_add`

- **Категория:** AI state · **Repo:** tourism-backend  
- **Evidence:** `chat_actions.py:345-364` — confirmed keys skip assignment, затем `interests_add` всё равно append. Тест только `city`/`people`.  
- **Scenario:** пользователь подтвердил «море»; модель шлёт `interests_add: ["горы"]`.  
- **Impact:** частичный reopen AI-6; generate уезжает от locked intent.  
- **Fix:** при `protect_confirmed` и `interests` in confirmed — игнорировать `interests_add`.  
- **Acceptance / test:** unit confirmed interests неизменны. **Confidence:** high · confirmed defect

#### BE-2026-06 — +5 тп выдаются с публичных GET без row lock

- **Категория:** races · **Repo:** tourism-backend  
- **Evidence:** `travel_points.py:37-83`; вызывается из `list_leaderboard` / `get_public_user` (`public_service.py:171,269`). Нет scheduler (это верно в docs).  
- **Scenario:** два GET лидерборда после 6h delay → двойное начисление.  
- **Impact:** кривые ранги; writes на read path.  
- **Fix:** `FOR UPDATE SKIP LOCKED` или host cron; не на anonymous GET.  
- **Test:** concurrent `grant_due_travel_points` → +5 once. **Confidence:** high · confirmed defect

#### BE-2026-07 — `leaderboard_place` на профиле считает экспертов

- **Категория:** Expert rank · **Repo:** tourism-backend  
- **Evidence:** список исключает expert (`public_service.py:175-184`); `_leaderboard_place` `:49-56` — `count(travel_points > points)` без фильтра ранга.  
- **Scenario:** эксперт с большими тп сдвигает «Топ N» обычного пользователя.  
- **Fix:** тот же `non_expert` predicate; экспертам `place=null`.  
- **Test:** expert выше A → public place A = индекс списка. **Confidence:** high · confirmed defect

#### BE-2026-08 — Кап 3 фото support — check-then-insert

- **Evidence:** `support/application/service.py:204-246`. Unique только avatar/cover, не gallery.  
- **Scenario:** parallel upload при count=2 → 4 файла.  
- **Fix:** lock ticket / partial unique; 409.  
- **Test:** `asyncio.gather` 4 upload → 3 active. **Confidence:** high · confirmed defect

#### BE-2026-09 / SEC-2026-08 — Profile/route image не ловят `DecompressionBombError`

- **Evidence:** support/review ловят (`attachments.py:60-61`); `identity/application/media.py:122-156` — только `UnidentifiedImageError`/`OSError` после `image.load()`.  
- **Scenario:** crafted huge-dimension image → 500 / spike RAM на 192 MiB.  
- **Fix:** `Image.MAX_IMAGE_PIXELS` до load; тот же except → 400 `invalid_image`.  
- **Test:** bomb payload → 400, не 500. **Confidence:** high · confirmed defect

#### BE-2026-11 / MO-2026-23 — Travel+ и quiz over-claim

- **Evidence:** `ai_rerank_applied=False` всегда (`match_service.py:74-84`); `alternatives_count` / multiplier / exclusive / offline flags в entitlements без call sites; `PATCH /me/preferences` есть, match/home не читают. Quiz: `preferences_repository.dart:81-88`; `_buildMatchParams` только local form (`route_match_screen.dart:362-381`).  
- **Impact:** paywall и «Сменить предпочтения» выглядят сломанными.  
- **Fix:** либо прокинуть prefs в scoring, либо явно «storage only» в UI/docs; не обещать 3 alternatives.  
- **Confidence:** high · documentation drift + product gap

#### BE-2026-12 — City picker / tools: unordered `LIMIT` + ILIKE

- **Evidence:** `place_picker.py:157-178` `limit(120)` без `ORDER BY`; `tool_registry.py` search ~40 unordered. `ST_Within` для районов — только в docs P0-bis.  
- **Impact:** после публикации OSM-set generate видит случайный срез.  
- **Fix:** locality_id / `ST_DWithin` + стабильный ORDER BY до LIMIT.  
- **Confidence:** high · confirmed quality defect

#### BE-2026-13 / SEC-2026-04 — OTP IP limit берёт первый `X-Forwarded-For`

- **Evidence:** `identity/presentation/router.py:26-29`; `ProxyHeadersMiddleware(trusted_hosts="*")` (`main.py:75-76`). Per-phone bucket всё ещё ограничивает одну жертву.  
- **Priority justification:** P2, не P1 — phone key остаётся.  
- **Fix:** IP от trusted proxy hop; Lua INCR+EXPIRE.  
- **Confidence:** high на коде; exploitability behind Caddy — needs manual verification

#### BE-2026-15 — `accept_proposal` грузит Place без publication filter

- **Evidence:** `generate_service.py:513-524` `session.get(Place, pid)`. Public catalog всё ещё прячет unpublished-stop routes.  
- **Impact:** owner draft может содержать embargoed place.  
- **Fix:** skip/422 unpublished. **Confidence:** high · confirmed (owner surface)

#### M-5 — Cross-module ORM imports vs ADR-001

- **Evidence:** application → чужие `infrastructure.models` в `route_builder`, `routes`, `favorites`, `identity`, `support`. Dependency test ADR-001 не существует.  
- **Kind:** architectural risk · **не split.** Сначала порты + import linter. **Confidence:** high

#### MO-2026-01 — Мёртвый `/search`

- **Evidence:** `search_screen.dart:7-24`; route `app_router.dart:138-143`; нет `push`/`go` на `AppRouteNames.search`. Нет back.  
- **Fix:** удалить или redirect `/` .  
- **Test:** router redirect. **Confidence:** high · confirmed defect

#### MO-2026-QA — `./scripts/validate.sh` красный на текущем mobile `main`

- **Evidence:** `dart format --output=none --set-exit-if-changed` → 9 test files; `flutter analyze --fatal-infos` → 11 infos `_welcomeCta` (`no_leading_underscores_for_local_identifiers`). При этом `flutter test` **269 passed**, goldens **25 passed**.  
- **Impact:** локальный CI-гейт врёт «нельзя мержить», либо его перестанут гонять.  
- **Fix:** format + rename locals (не подавлять `--fatal-infos`).  
- **Confidence:** high · confirmed defect

#### MO-2026-03 — Нет a11y-контракта на icon buttons

- Glass/flat требуют `semanticLabel`; `SettingsCircleIconButton` (`settings_widgets.dart:339-384`) — ни tooltip ни Semantics; raw `IconButton` на results/city clear.  
- **Fix:** Phase 7 плана 25 августа — `AppIconButton` contract. **Confidence:** high

#### MO-2026-04 — Home vs catalog cache keys; bootstrap не греет home places

- `homePlacesProvider` limit 20; `placesListProvider` 50; `app.dart` не watch `homePlacesProvider`. **Confidence:** high

#### MO-2026-12 — `EntityReviewsSection` hardcoded colors (merge debt фазы 6)

- `entity_reviews_section.dart:695-794,848-864,1261-1264` — `Color(0xFFE4E4E6)` и др. вместо `AppColors`/`AppRadii`. **Confidence:** high

#### MO-2026-13 / MO-2026-14 — Unbounded thumbs; eager Column

- Review strip `imageProvider` без `memCacheWidth`; inbox/chat history `Column`+`for`. Caps 50/100 смягчают. **Confidence:** high · static signal

#### MO-2026-21 — `chatSessionsProvider` не инвалидируется после нового чата

- Invalidate только на retry (`chat_history_screen.dart:87`). `startNewChat` не трогает. **Confidence:** high

#### MO-2026-22 — Double submit checkout / accept proposal

- Checkout `_submit` без `_busy` (`settings_travel_plus_checkout_screen.dart:60-91`); `acceptProposal` без in-flight guard. **Confidence:** high

#### MO-2026-20 — All-list «поиск» — overlay на 8 hits, фильтров нет; ошибка next-page тихая

- Spec обещает search+filters; код `showFilterButton: false`. **Confidence:** high

#### MO-2026-25 — Ошибки upload фото support проглатываются

- `settings_support_screens.dart:1521-1535` catch per file без UI; тикет уже создан. **Confidence:** high

#### SEC-2026-05 — Нет app rate-limit на chat/generate/uploads

- OTP/admin limited; chat держит GPU 60 с; route media **50 MB**. **Confidence:** high

#### SEC-2026-06 — `file://` в `avatarProvider`/`imageProvider` до allowlist

- `app_images.dart:170-171`; `resolveMediaUrl` `file:` отвергает. Mock auth пишет `file://` после picker. API сегодня отдаёт `/media/...`. **Confidence:** medium (exploitability)

#### SEC-2026-11 — Keyword-only injection/crisis filter

- `topic_guard.py:94-117`. Tools всё ещё не BOLA. Это UX-фильтр, не контроль. **Confidence:** high

#### SEC-2026-12 — Нет backup/restore в дереве

- Docs T5.6.2 всё ещё open; нет `pg_dump` scripts. **Confidence:** high

#### SEC-2026-18 — Lean GitLab CI не гоняет security gates

- Backend `.gitlab-ci.yml` web-only publish. `pip-audit`/pytest только локально. **Confidence:** high

#### ARC-2026-04 — В проекте нет планировщика

- Нет cron/APScheduler/celery. Recs backend и delayed тп упираются в это. **Kind:** architectural risk · **Fix:** ADR host crontab + CLI, не Kafka.

#### ARC-2026-05 — Difficulty: int 1–5 vs enum vs mobile `expert`

- `_difficulty_name`: 4 и 5 → `hard` (`routes/application/service.py:473-478`). Mobile `expert` → 5, backend так не пишет. **Confidence:** high

#### ARC-2026-06 — Place API богаче клиента; `opening_hours_raw` нет в DTO

- `PlaceDetailOut` имеет `freshness_status`, `primary_entrance`, prices (`schemas.py:56-75`); `opening_hours_raw` на ORM (`places/infrastructure/models.py:143-145`), **нет в schemas**. `PlaceDetail.fromJson` (`place.dart:93-117`) берёт description/address/seasonality/safety/images. `PlaceSchedule` — только модель, 0 application reads.  
- **Impact:** турист не видит часы/вход/свежесть. **Confidence:** high

#### PERF-BE-04 — Support `list_tickets` N+1

- `support/application/service.py:152-171` — messages + attachments на каждый ticket. **Static signal**

#### PERF-MO-02 — Support chat poll 3 с

- Mobile `_refreshInterval = 3s`; admin HTML `POLL_MS = 3000`. **Static signal**

#### DOC-2026-04 — Platform README: «planning API ещё нет»

- См. DOC-2026-01; отдельный onboarding door. **Confidence:** high

#### DOC-2026-12 — Копирайт «подборки каждый день» при RAM-only skip

- Spec честно говорит, что daily false; UI обещает ежедневное обновление. **Confidence:** high · product copy

---

### P3 (кратко)

| ID | Title | Evidence | Kind |
| --- | --- | --- | --- |
| BE-2026-14 | Concurrent Travel+ activate → 500 | unique index без lock; IntegrityError → generic 500 | hypothesis / ugly 500 |
| MO-2026-02 | Identity screen без back на welcome | `auth_identity_screen.dart`; spec документирует | product question |
| MO-2026-05 | `listMyRoutes` bypass TTL | `caching_routes_repository.dart` | architectural |
| MO-2026-06 | `publicProfileProvider` watch всего session | `profile_providers.dart:168` | confirmed |
| MO-2026-15 / SEC-2026-14 | Path params без UUID gate | backend UUID всё равно 422 | architectural |
| MO-2026-16 / SEC-2026-15 | Firebase client keys в бандле | ожидаемо; App Check не проверен | needs ops verification |
| MO-2026-17 / SEC-2026-16 | Keychain `first_unlock` | `secure_storage_provider.dart:10` | product trade-off |
| MO-2026-32 | Нет App Links | Android MAIN/LAUNCHER only | architectural |
| MO-2026-33 | Нет l10n | hardcoded RU | OK for MVP |
| SEC-2026-03 | 4-digit OTP unsalted SHA-256 + debug_code | `crypto.py:6-22`; SEC-EX-2026-001 до 2026-10-31 | accepted exception |
| SEC-2026-07 | Local any http(s) media host | `app_images.dart:143-145` | local only |
| SEC-2026-09 | Access JWT не revoke до TTL | documented 15 min | accepted |
| SEC-2026-10 | `trusted_hosts="*"` | `main.py:75-76` | needs deploy verification |
| SEC-2026-17 | FCM token upsert rebind | `device_tokens.py:19-35` | confirmed low likelihood |
| SEC-2026-19 | `threat-model.md` таблицы Phase-3 | vs `security-as-built.md` | docs |
| ARC-2026-10 | FastAPI `/docs` включён, version `0.1.0` | `main.py` | harden prod |
| ARC-2026-11 | Place-review approve без inbox | route-only notification helper | confirmed |
| DOC-2026-21 | Нет `AGENTS.md` | Codex/onboarding | process |
| PERF-MO-05 | Home precache `cacheWidth: 1080` | `home_screen.dart:167` | hypothesis |
| AI-11 residual | `.env.example` gemini/ollama; RAG hash-v1 | config/factory | docs + ADR-009 as-built |

---

## Backend review

Modular monolith (ADR-001) **правильный** на один VPS и одну команду. `route_builder` — самый связанный пакет; вынос в сервис даст distributed monolith. LM Studio уже out-of-process — оформлять **зависимостью** (слот + метрики сделаны), не микросервисом.

Слои в целом presentation → application, но application систематически импортирует чужие ORM (M-5). Транзакции: один use-case ≈ один commit, кроме chat, который держит сессию на HTTP (BE-2026-03).

Миграции линейны `0001`–`0037`. Spatial GIST на `places.location` есть. P0-bis `ST_Within` по `Locality.boundary` **не реализован** (колонки есть).

Заглушки vs docs: **живой** route_builder + subscriptions; **пустой** только `route_execution/__init__.py`. Routing factory принимает только `"stub"` (`routing_factory.py:12-16`, `_ROAD_FACTOR = 1.35`). Embedder `hash-v1`; `ai_planning_enabled` / `rag_enabled` default **False**.

Нет: cron, Prometheus, OpenTelemetry, backup scripts, recommendations tables, execution API.

---

## Mobile review

Feature-first для places/routes/auth/route_match соблюдён; AllList и generate на results ходят в repository из presentation (MO-2026-24 class). `RouteMatchNotifier` — удачное извлечение; экран ~838 LOC UI.

User journey:

| Шаг | Статус |
| --- | --- |
| Welcome → OTP → Home | работает; identity без back; mock OTP любой 4-digit |
| Каталог / «Смотреть все» | работает + гонка пагинации |
| Swipe deck | in-session; skip в RAM |
| Карточки | работают; audio/share/offline/walk — stub/snackbar |
| Избранное | save/undo ок; вкладка «История» = `routes.take(6)` каталога |
| Подбор → generate | работает |
| Travel+ AI chat + history | работает при подписке; history list stale; Dio 20 с |
| Пройти маршрут | **stub** (`app_shell_screen.dart:235-239`) |

`DATA_SOURCE=mock` запрещён вне local. Design tokens: Home/hero/audio в системе; reviews — pre-token merge debt. A11y: примитивы glass/flat хорошие, Settings circle — нет.

`validate.sh` на `e1b8fbbb` **не проходит** (format + fatal-infos), при зелёных 269+25 тестах.

---

## Security review

### Threat model (as-built)

**Активы:** OTP digest (+ debug_code на test), JWT signing key, refresh digests, admin cookie/Argon2id, телефоны, private routes, AI chat, support photos, FCM tokens, каталог (public).

**Границы:** Device Keychain → HTTPS → Caddy → FastAPI → Postgres/Redis/MEDIA_ROOT; отдельно LM Studio (operator URL) и FCM.

**Персоны:** anonymous internet; malicious user; intercepting proxy; stolen device; ops admin; DB insider; compromised model; local DX attacker.

**Entry points:** OTP/refresh, Bearer APIs, public catalog, `/media/**`, cookie `/admin`, operator import scripts, GoRouter/FCM data.

AuthN/AuthZ в целом соответствуют as-built: UUID не право; planning session `_owned_session`; favorites/tickets по `user_id`. CSRF для native Bearer N/A; для `/admin` — есть.

**P0 exploitable на production-конфиге не найден.** Главные P1 — capability-URL media и публичный `/admin`.

Секреты: tracked PEM/AKIA/ghp не найдены. `.env` gitignored (файлы локально есть, не читались). Firebase client keys в бандле — ожидаемо.

---

## Performance / reliability

Разделение: **измеренное** / **статический сигнал** / **гипотеза**.

| ID | Label | Что |
| --- | --- | --- |
| BE-2026-03 | static | DB checkout на время AI |
| PERF-MO-01 | static (в составе BE-2026-03) | Dio 20 с vs AI 60 с |
| BE-2026-12 | static | ILIKE + unordered LIMIT |
| PERF-BE-04 | static | support N+1 |
| PERF-BE-07 | static | default pool |
| PERF-BE-05 | hypothesis | 192 MiB vs Pillow+chat |
| PERF-MO-03/04 | static | eager lists, unbounded decode |
| PERF-MO-02 | static | 3s poll |
| Swipe jank | hypothesis | фаза 4 уменьшила rebuild; blur/340ms settle не профилировались |
| Redis down | static | OTP fail-closed (правильно); login недоступен |
| LM Studio down | static | soft fallback чата |
| FCM down | static | inbox остаётся |

EXPLAIN/нагрузка **не запускались** — ни один SQL не назван «медленным измерением».

---

## Test quality

**Защищено хорошо:** OTP/BOLA/favorites/publication/Travel+ env gate/support ownership/admin CSRF; concurrent refresh и generate-quota; chat allowlist widget; RouteMatchNotifier behavioral; Travel+ activate; hero/home rebuild-scope.

**Зелёные при сломанном продукте:**

- Expert tests без catalog title → BE-2026-01 не ловится.
- Support media test не делает anonymous GET файла.
- `protect_confirmed` не покрывает `interests_add`.
- `search_screen_test` тестирует in-place search, скрывая мёртвый `/search`.
- History tab `take(6)` не assert «это не история прохождений».
- Quiz не проверяет влияние на match.
- AllList race нет теста.
- Нет `integration_test` onboarding→catalog→favorite→match→chat.
- Coverage `--cov-fail-under=74` (74.64% в этом прогоне) не значит, что security suite — единственный сигнал; `session_service.py` 44% cover, generate 44%.
- Mobile `validate.sh` красный, `flutter test` зелёный — ложное чувство «можно мержить без format».

**Минимальная пирамида следующего релиза:** существующий `tests/security` + новые GET `/media` + expert catalog + concurrent chat; mobile: pagination race, chatSessions invalidate, format/analyze green, один journey OTP→session (не полный AI).

---

## Documentation drift

Помимо DOC-2026-01/02/03/04/12:

- `application-business-logic.md` §3 ещё кладёт UGC/Travel+ в «будущее», §11/13 описывают as-built.
- `product-vision.md` MVP: route builder «ещё не реализован».
- `threat-model.md` таблицы «auth not implemented» / «future admin».
- `development-conventions.md` модель `gemma4:12b` vs stack 26B.
- `phase-and-screens-map.md` заморожен 2026-08-01.
- Spec auth back: OTP **уже** с кнопкой «Назад»; identity нет.
- OpenAPI «из FastAPI» заявлен, `openapi.json` не коммитится; клиент hand-written — отсюда difficulty drift.
- ADR-002 всё ещё упоминает несозданные `tourism-infrastructure` / `tourism-documentation`.
- `event-catalog.md` читается как живая шина.
- Нет корневого `AGENTS.md` (пользовательская инструкция Codex); правила только в `.cursor/rules`.

Канон для дизайна/QA: `mobile-screens-business-spec.md` — лучший as-built; screens map можно архивировать.

---

## Product / roadmap analysis

Концепция: найти место → понять условия визита → получить проходимый маршрут → пройти его.

As-built закрывает **найти (частично) + социальную оболочку**. Условия визита (часы, вход, freshness) есть в БД/частично в API и **не на экране**. Проходимый маршрут — синтетика 1.35. Прохождение — нет.

ADR-009 верен: рычаг — published places + районы, не эмбеддер и не новый чат UI.

**Не делать сейчас:** микросервисы, Kafka, K8s, Gemini, Qdrant, RAG on hash-v1, Store billing, Trip Planner, notification CMS, Mapillary, полный offline-навигатор, client codegen OpenAPI как проект.

Реалистичная последовательность: docs-честность → Expert/media/admin → AI lifecycle → pagination/catalog filters → P0-bis districts + editorial publish → recs v1 + cron ADR → execution v0 → OSRM когда точек достаточно → SMS когда есть что показать незнакомцу.

---

## Идеи развития (не дефекты)

### Quick wins (дни)

| Идея | Проблема | Эффект | Сложность | Зависимости | Метрика | Почему сейчас |
| --- | --- | --- | --- | --- | --- | --- |
| Честные CTA walk/audio/daily deck | Копирайт врёт | Доверие | S | нет | жалобы в support | дешево |
| Показать `opening_hours_raw` + freshness + entrance | Турист не понимает «можно ли ехать» | Ближе к vision | S–M | additive DTO | coverage часов на карточках | колонка уже есть |
| Prefill match из `PATCH /me/preferences` | Quiz мёртвый | Персонализация без ML | S | `0036` | match ideal rate | данные уже пишутся |

### Ближайший релиз (1–3 недели)

| Идея | Сложность | Зависимости | Почему важнее альтернатив |
| --- | --- | --- | --- |
| P0-bis районы `admin_level=6` + `ST_Within` | M | OSM boundaries | 700 мест без города — последний открытый P0-bis |
| Editorial publish Wikipedia-ready (ops) | M ops | гейт, фото | единственное, что делает match «про Крым» |
| Серверные фильтры + пагинация каталога | S–M | ARC-2026-07 | иначе 141 published бесполезны в UI |
| Recommendations v1 + skip persist | M | cron ADR | клиент уже finite deck |
| Place-review inbox parity | S | notification kinds | документированный пробел |

### Средний горизонт (1–3 месяца)

- Route execution v0 (check-ins без GPS-продукта) — закрывает loop и тп с прогулок.
- OSRM Crimea (P2 roadmap) — **после** реального каталога.
- SMS OTP — до store listing, после контента.
- P1 embedder — только на text-rich published corpus.

### Стратегия (после метрик)

Travel+ Store billing, CMS вместо SQLAdmin, campaign notifications, ML recs / weather rerank, полный offline pack — **не до** того, как турист видит часы и может «начать маршрут».

Оценка тем: персональные рек — quiz как prior, не ML; маршрутные рек — backend v1; OSRM — рано до данных; quality places — **главный рычаг**; offline — pack одного маршрута после execution; AI planning — не расширять UI; Travel+ — entitlements ок, billing нет; admin — SQLAdmin хватает, время на publish; notifications — place-review, не кампании; observability — JSON extras + host alerts; analytics — first-party skip/favorite, без стороннего SDK.

---

## Список выполненных проверок

| Проверка | Результат |
| --- | --- |
| Git status workspace + 3 submodule | чисто; stash mobile на месте |
| `tourism-platform/scripts/validate.sh` | **OK** (required files, compose, markdownlint 0, yamllint) |
| `tourism-backend/scripts/validate.sh` | **OK** — ruff pass, format 281 files, mypy 170 files, pip-audit no known vulns, **406 passed, 1 skipped**, coverage **74.64%** (≥74) |
| Skipped backend test | `test_covers_for_places_skip_unpublished_place_media` — нет unpublished place с active cover в локальной БД |
| Mobile `dart format --output=none --set-exit-if-changed` | **FAIL** — 9 test files |
| `flutter analyze --fatal-infos` | **FAIL** — 11 infos `_welcomeCta` |
| `flutter test` | **269 passed** |
| `flutter test test/golden` | **25 passed** |
| Backend `uv run pytest tests/security` (внутри validate) | часть 406; субагент отдельно: 132 passed, 1 skipped |
| Secret pattern grep PEM/AKIA/ghp/xox | нет в tracked globs |
| gitleaks / trivy / DAST / production | **не запускались** |
| Чтение `.env` | **не выполнялось** |

`./scripts/validate.sh` mobile **целиком не зелёный** (падает на format до analyze/test). Не чинилось, чтобы «сделать зелёным».

---

## Фазы remediation (сводка)

Полный backlog: [2026-08-27-review-remediation-plan.md](2026-08-27-review-remediation-plan.md).

| Фаза | Содержание | Сложность | Repo |
| --- | --- | --- | --- |
| R0 | Честная карта: README stubs, фазы, ADR-008→010 | S | platform + READMEs |
| R1 | `/media` auth для support; admin lock-down | M | backend + platform deploy |
| R2 | Shared Expert rank resolver + leaderboard_place | S | backend |
| R3 | Chat: не держать DB; session lock; Dio timeout | M | backend + mobile |
| R4 | AllList generation token; chatSessions invalidate; checkout busy; format/analyze | S | mobile |
| R5 | Catalog API filters/pagination + place hours on card | M | both |
| R6 | Старый mobile Phase 7–8 (search delete, tokens, a11y, thumbs) | M | mobile |
| R7 | P0-bis districts + editorial publish (ops) | M | backend + ops |
| R8 | Recs v1 + cron ADR | M | backend + platform |
| R9 | Route execution v0 | L | backend + mobile |

---

## Порядок выполнения

R0 параллельно с R1–R2 (docs не блокируют security). R3 до расширения чата. R4 сразу (user-facing). R5 перед массовой публикацией. R7 — продуктовый рычаг ADR-009. R8 после cron ADR. R9 после того, как есть что проходить. OSRM / SMS / billing — после R7+R9.

---

## Зависимости между задачами

- R1 media URLs → mobile image loader.
- R3 timeout → согласовать client/server.
- R5 обязателен перед «опубликовать 141».
- R7 районы разблокируют часть publication gate.
- R8 требует ARC-2026-04 (планировщик).
- R9 требует новые таблицы; тп-с-прогулок завязаны на него.
- Expert R2 независим.
- Dual ADR-008 закрыть до любого нового ADR.

---

## Release gates

Перед следующим production APK / backend image:

1. R1 media: anonymous GET support → не 200.
2. R2 Expert title согласован на `/routes` и reviews.
3. Mobile `validate.sh` зелёный (format + analyze --fatal-infos + tests).
4. Backend `validate.sh` зелёный (уже в этой сессии).
5. AI: либо Dio timeout поднят, либо server ≤ 20 с; нет silent client retry storm.
6. Docs R0: README не называет route_builder stub.
7. Не включать `RAG_ENABLED` / не обещать daily decks / walk.

---

## Осознанно откладывается

- Микросервисы, Kafka, Kubernetes, Gemini adapter, Qdrant.
- Upgrade `hash-v1` (ADR-009).
- OSRM до реального published каталога.
- Store billing / exclusive Travel+ catalogs.
- Trip Planner (Phase 13).
- Notification campaign CMS.
- Access-token denylist (15 min accepted, пока нет инцидента).
- Keychain `this_device` — продуктовый trade-off backup.
- i18n, App Links, полный offline.
- Вынос SQLAdmin в CMS.

---

## Решения, требующие ADR

1. **Renumber:** ops-admin → ADR-010; pgvector остаётся ADR-008.
2. **ADR-011 — LM Studio as process-external dependency** (не сервис; DB не держать на HTTP).
3. **ADR-012 — Expert is a `travel_ranks` row** (инвариант title/leaderboard).
4. **ADR-013 — Host job runner (cron + idempotent CLI)**, не брокер.
5. **ADR-014 — Public vs authenticated media prefixes.**
6. Позже: SMS provider (wind-down SEC-EX-001); OpenAPI snapshot; privacy/analytics только если появится телеметрия; embedder swap как amendment ADR-009.

Не писать ADR на Kafka/K8s/billing.

---

## Acceptance criteria этого ревью

Ревью считается полным: SHA зафиксированы; P0/P1 перепроверены по текущему `main`; старые фазы 0–6 закрыты явно; план ремедиации достаточно конкретен для отдельных implementation-задач; проверки запущены и не подделаны.
