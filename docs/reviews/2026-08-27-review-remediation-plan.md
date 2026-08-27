# 2026-08-27 review remediation plan

Date: 2026-08-27  
Source: [2026-08-27-full-project-review.md](2026-08-27-full-project-review.md)

Reviewed SHAs (do not treat older reviews as current):

| Repo | `main` |
| --- | --- |
| workspace | `bd91437a4be99d735a960c6ae3b4b892caae2a50` |
| tourism-backend | `80cdba144989754c7ee069d33cbbc5152e60bd0e` |
| tourism-mobile | `e1b8fbbb5089c08d272651ad5d2eded4ca15767c` |
| tourism-platform | `6343cd07ea5753aea8b0f53c0fed7c1b91d3a01a` |

Не план продукта на год — приоритизированный backlog, с которого можно сразу резать ветки. Каждая фаза shippable сама. Не блокировать N+1 на полное закрытие N, кроме явно указанных зависимостей.

Фазы **0–6 ревью 2026-08-25 смержены** и здесь не повторяются, кроме долга 7–8, который вошёл в R6.

Нумерация: **R0–R9** (review-remediation 2026-08-27), чтобы не путать с Product Phase 8A/8B и Route-intelligence P0–P4.

---

## Goals

1. Убрать два реальных security-зазора ближайшего контура: публичные support-файлы и открытый `/admin`.
2. Починить сломанный инвариант «Эксперт» на карточках — фича уже в `main` (`432df1c`).
3. Сделать AI-чат честным по таймаутам и транзакциям (20 с Dio vs 60 с LM Studio + занятый DB pool).
4. Закрыть user-facing гонки (AllList) и красный mobile `validate.sh`.
5. Выровнять карту проекта (README/фазы/ADR-008), иначе команда будет строить уже существующее.
6. Разблокировать ADR-009: серверные фильтры каталога → районы → публикация, не новый AI.

---

## Phase R0 — Честная карта проекта (docs)

Priority: immediate, parallel with R1. Complexity: **S**. Repo: `tourism-platform` + README workspace/backend.

- [x] **DOC-2026-01 / DOC-2026-04** — README workspace/backend/platform синхронизированы с live Route Builder и planning sessions.
- [x] **DOC-2026-02** — progress обновлён с явным разделением review remediation R0–R9 и продуктовых фаз; закрытые R2/R4 отмечены.
- [ ] **DOC-2026-03** — pgvector остаётся **ADR-008**; ops-admin → **ADR-010** + redirect-stub. Прогнать grep `ADR-008`.
- [ ] Optional: одна страница «As-built in 15 minutes» (published-only catalog, stub routing, OTP local vs test vs prod, как выдать Travel+, какой `validate.sh`).
- [ ] Optional: корневой `AGENTS.md` со ссылкой на `tourism-platform/docs/` (DOC-2026-21).

**Acceptance:** grep не находит «пакеты без router» рядом с `route_builder`; один ADR-008 файл; progress table = changelog.  
**Tests:** markdownlint / существующий platform `validate.sh`.  
**Не код продукта.**

---

## Phase R1 — Media delivery + admin surface (P1 security)

Priority: immediate. Complexity: **M**. Repo: `tourism-backend`, чуть `tourism-platform` deploy, возможно mobile URL.

- [ ] **SEC-2026-02** — `support/` (и pending review objects) не отдавать через голый `StaticFiles`. Authenticated GET или signed short-TTL URL. Каталог `/media/places|routes|profiles` можно оставить публичным.
- [ ] Security test: anonymous GET support `public_path` → 401/404; owner 200; stranger 404.
- [ ] **SEC-2026-01** — IP allowlist или отдельный host для `/admin` в `deploy/test/Caddyfile`; `Secure` cookie на любом HTTPS contour включая `test`, если он в интернете; не показывать `debug_code` на сетевом контуре. MFA — отдельный follow-up, не блокер патча allowlist.
- [ ] **BE-2026-09** (рядом, тот же upload-контур): ловить `DecompressionBombError` на profile/route, как на support/review; `Image.MAX_IMAGE_PIXELS` до `load()`.

**Acceptance:** критерии в full review SEC-2026-01/02, BE-2026-09.  
**Breaking:** mobile должен уметь грузить support-фото с нового URL/заголовка.  
**Depends:** нет (кроме согласования URL с mobile).  
**ADR:** ADR-014 public vs authenticated media (можно коротким amendment, если не хочется нового номера до R0).

---

## Phase R2 — Expert rank consistency (P1)

Priority: immediate. Complexity: **S**. Repo: `tourism-backend`. Independent of R1.

- [x] **BE-2026-01** — Expert-aware rank resolution подключён в routes и обоих review services.
- [x] **BE-2026-07** — `_leaderboard_place` использует non-expert predicate; экспертам возвращается `null`.
- [x] Tests: unit Expert rank и public leaderboard regression; target suite зелёный.

**Acceptance:** карточка маршрута, match, review byline и профиль показывают одно звание.  
**ADR:** ADR-012 (можно после кода).

---

## Phase R3 — AI request lifecycle (P1 reliability)

Priority: high. Complexity: **M**. Repo: `tourism-backend` + `tourism-mobile`.

- [ ] **BE-2026-03** — `SELECT … FOR UPDATE` на `route_planning_sessions` в начале `post_message`.
- [ ] Commit user-turn (или отдельная короткая сессия) **до** HTTP в LM Studio; не держать pool checkout 60 с.
- [ ] Явные `pool_size` / `pool_timeout` под test compose (`max_connections=20`, 1 worker).
- [ ] **Timeout contract:** Dio `receiveTimeout` ≥ server AI timeout **или** server timeout ≤ 20 с + понятная ошибка. Задокументировать.
- [ ] Optional: idempotency key на `RoutePlanningMessageIn`.
- [ ] **BE-2026-05** (маленький, тот же файл): `interests_add` уважает `protect_confirmed`.

**Acceptance:** concurrent POST не last-write-wins без блокировки; `/health/ready` жив при N чатах; клиент не рвёт раньше сервера.  
**Tests:** concurrent `post_message`; unit `interests_add`; по возможности fake delay + catalog still fast.  
**Depends:** нет. Не блокировать R4.  
**ADR:** ADR-011 LM Studio as external dependency.

---

## Phase R4 — Mobile correctness + green validate (P1/P2)

Priority: high. Complexity: **S**. Repo: `tourism-mobile`. **Не трогать** `stash@{0}`.

- [x] **MO-2026-QA** — format/analyze/test/goldens проходят; `_welcomeCta` переименован.
- [x] **MO-2026-19** — generation token на `AllListScreen`; stale responses игнорируются.
- [ ] **MO-2026-21** — `ref.invalidate(chatSessionsProvider)` после `startNewChat` / create session.
- [ ] **MO-2026-22** — `_busy` на Travel+ checkout; in-flight guard на `acceptProposal`.
- [ ] **MO-2026-25** — не глотать upload ошибок фото support.
- [ ] **MO-2026-01** — удалить `SearchScreen` route или redirect `/search` → `/`.

**Acceptance:** validate.sh green; race test; history показывает новый чат без kill process.  
**Tests:** delayed fake listRoutes/listPlaces + mode switch; chatSessions after create; checkout double-tap; router `/search`.

---

## Phase R5 — Catalog usable after publish (P1 product)

Priority: high, **перед** массовой публикацией 141 мест. Complexity: **M**. Repos: `tourism-mobile` + additive backend если нужно.

- [ ] **ARC-2026-07 / MO-2026-20** — `listPlaces`/`listRoutes` с `q`, category, offset; all-list search не подменять overlay на 8 hits; показать ошибку next-page.
- [ ] Home chips — таксономия/API, не substring `ялт`.
- [ ] **ARC-2026-06** — additive DTO `opening_hours_raw` (хотя бы raw); mobile `PlaceDetail.fromJson` + UI часов / freshness / primary entrance (поля API уже частично есть).
- [ ] **MO-2026-23 / BE-2026-11** — либо prefill match из preferences, либо copy «сохранено, подбор пока не использует». Снять `alternatives_count=3` из пользовательских обещаний, пока generate не умеет 3 варианта.

**Acceptance:** страница 2 каталога и фильтр категории бьют сервер; на карточке видны часы, если колонка заполнена.  
**Depends:** желательно до R7 publish ops.  
**Cache:** учесть разные cache keys (MO-2026-04) в том же PR, если трогаете providers.

---

## Phase R6 — Mobile cleanup (бывшие Phase 7–8 от 2026-08-25)

Priority: medium. Complexity: **M**. Repo: `tourism-mobile`.

- [ ] A11y contract: icon button без label не собрать (`SettingsCircleIconButton`, raw `IconButton` на match).
- [ ] `EntityReviewsSection` → `AppColors` / `AppRadii` (8 hex, 13 radii).
- [ ] Unbounded thumbs: review strip, audio 44×44, avatars — `memCacheWidth`.
- [ ] Inbox / chat history → `ListView.builder`.
- [ ] Узкий `.select` на оставшихся `sessionProvider` (match, reviews, profile).
- [ ] **SEC-2026-06:** `file://` только для sandbox picker, не для API URL.
- [ ] Auth identity back → welcome (продуктовое решение; OTP back уже есть).
- [ ] Motion: deck settle vs `AppMotion.emphasized`; не обязательно в этом же PR.

**Acceptance:** analyze чист; goldens; a11y test на Settings circle.  
**Depends:** R4 format, чтобы validate не врал.

---

## Phase R7 — Data-first: districts + publish (ADR-009)

Priority: product lever, not a code-bug phase. Complexity: **M** (ops + небольшой backend). Repo: `tourism-backend` + ops.

- [ ] P0-bis: импорт OSM `admin_level=6`, `ST_Within` → `locality_id` / `parent_locality_id` для ~700 мест без города.
- [ ] Editorial publish Wikipedia-backed ready set (гейт уже есть). Не dump 5000 drafts.
- [ ] **BE-2026-12** — picker/tools: ORDER BY + locality / `ST_DWithin`, не unordered LIMIT 40/120.

**Acceptance:** publication report: locality null rate падает; published с описанием и cover растёт осмысленно.  
**Depends:** R5, иначе UI не покажет новые места честно.  
**Not:** включать RAG / hash-v1 «потому что данные появились».

---

## Phase R8 — Recommendations v1 + host cron

Priority: medium, после R7 или параллельно с маленьким editorial set. Complexity: **M**. Repos: `tourism-backend`, `tourism-platform`.

- [ ] **ADR-013** host crontab + idempotent CLI (не Kafka, не K8s CronJob).
- [ ] Таблицы `route_recommendation_feedback` / `route_recommendation_deck_items` как в `route-swipe-recommendations.md`.
- [ ] `GET .../recommendations/today`, `POST .../skip`.
- [ ] Честный copy вместо «каждый день», пока cron не жив (DOC-2026-12 можно закрыть в R0 текстом, здесь — правдой в проде).
- [ ] **BE-2026-06** — вынести grant +5 тп с публичного GET на тот же cron (`FOR UPDATE SKIP LOCKED`).

**Depends:** ADR-013. Mobile deck уже finite.

---

## Phase R9 — Route execution v0

Priority: closes the core loop. Complexity: **L**. Repos: both.

- [ ] Не snackbar: start / check stops / complete без live GPS-навигатора.
- [ ] History tab в Избранном — реальные прохождения, не `routes.take(6)`.
- [ ] Тп/achievements с прогулок — только после этой фазы (не выдумывать unlock-from-km раньше).

**Depends:** есть published маршруты, которые имеет смысл проходить (R7). OSRM не обязателен для v0.

---

## Explicitly not now

- Микросервисы / split `route_builder`.
- Kafka, Kubernetes, Helm.
- Gemini adapter, Qdrant, MCP, RAG в prod на `hash-v1`.
- OSRM до реального published каталога (потом P2 roadmap).
- Store billing / exclusive catalogs / ads.
- Trip Planner (Product Phase 13).
- Notification campaign CMS (T6.5.3).
- Mapillary.
- Access JWT denylist (15 min accepted).
- i18n, App Links, полный offline navigator.
- Client codegen OpenAPI как проект (сначала snapshot, если понадобится).

---

## Suggested branch names

`fix/<short-name>` from `main`, Conventional Commits, one meaning per commit (см. `development-conventions.md`).

Примеры: `fix/support-media-auth`, `fix/expert-rank-resolver`, `fix/chat-db-session`, `fix/all-list-pagination`, `docs/as-built-map`.

---

## Release gates (повторение)

1. Anonymous GET support media ≠ 200.  
2. Expert title согласован.  
3. Mobile `./scripts/validate.sh` green.  
4. Backend `./scripts/validate.sh` green.  
5. AI timeout client/server согласованы.  
6. README не врёт про stubs.  
7. Не включать RAG; не обещать walk/daily decks, пока их нет.

Перед commit/push — skill `travel-platform-local-ci`. Не `git push` без явной просьбы.

---

## Mapping old 2026-08-25 leftovers → this plan

| 2026-08-25 | 2026-08-27 |
| --- | --- |
| Phase 7 SearchScreen, auth back, a11y, cache keys | R4 (`/search`) + R6 |
| Phase 8 tokens, thumbs, Columns, SEC-2/3/5/6/7, docs Gemini | R6 + R0 (docs) |
| M-5 cross-ORM | не отдельная фаза; постепенно, dependency test когда чистите первый модуль |
| AI-11 docs | R0 |
| Explicitly not now (split / RAG / OSRM) | без изменений |
