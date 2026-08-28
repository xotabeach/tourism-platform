# План следующего инкремента: 2ГИС, маршруты, персонализация и offline

Дата: **2026-08-28**  
Статус: **исполняемый план / backend-first**  
Владелец: product + backend + mobile + platform

Документ объединяет новые требования после выдачи тестового ключа 2ГИС:
карты и навигацию, реалистичность маршрутов, обновление каталога,
персонализацию, prompt, offline-доступ, hand-off в приложение 2ГИС, Apple
WidgetKit и Dynamic Island. Он дополняет [единый blueprint](implementation-blueprint-2026-08.md),
а не отменяет ADR-010/ADR-011.

Главный принцип: сначала подтверждённые данные и понятный пользовательский
сценарий, затем автоматизация. Ответ внешнего API не считается доказательством
того, что горная тропа безопасна, открыта или подходит ребёнку.

## 1. Решение на сегодня

### Уже реализовано в текущем рабочем срезе

| Область | Что есть | Ограничение, которое явно показываем |
| --- | --- | --- |
| 2ГИС backend | `TwoGisRoutingProvider`, server-side HTTP, `walking`/`driving`, detailed WKT, фильтры, altitude normalization, typed errors | feature flag по умолчанию остаётся `stub`; нужен test smoke с реальным ключом |
| Данные generated route | provider geometry сохраняется вместо прямой линии; v1 quality gate проверяет geometry, leg metrics, mode/road contradictions, уклон, набор высоты, stop-data и region road events; execution повторно блокирует актуальное closure; время движения/остановок/итог разделено | полный independent terrain/water/access gate ещё впереди |
| Route detail | API отдаёт валидированную GeoJSON LineString, provenance, quality status/warnings, высоты и breakdown времени; mobile рисует эту линию и показывает понятный quality notice; execution получает revision-linked snapshot | полноценная карта 2ГИС, attribution и Active Route ещё впереди; retention cleanup уже добавлен |
| Preferences | categories/difficulty/kids/pets участвуют в мягком backend scoring | это prior, а не жёсткий фильтр; поведение и diversity deck ещё впереди |
| Mobile prompt | один invitation после загрузки API-профиля, переход в экран предпочтений, «Позже» | в local/mock не показывается, чтобы не ломать preview и тесты |
| Preferences UI | лёгкая intro-карточка, иконки, счётчик, очистка и полный сброс | поля соответствуют текущему API, новые поля добавляем только через контракт |
| Offline route snapshot | JSON полного `RouteDetail`, локальный список, удаление одной/всех копий, fallback detail при ошибке сети | это read-only snapshot; offline map tiles, outbox и namespace аккаунта — следующий этап |
| Logout | revoke refresh token + очистка локальных route snapshots + cache invalidation | secure storage токена не смешивается с SharedPreferences |

### Что сознательно не включаем в первый production rollout

- demo HTTP key в мобильный bundle;
- нативный 2ГИС SDK до отдельной subscription/licence key;
- постоянный GPS, background location и скрытое начисление rewards;
- обещание «навигация» для synthetic/unverified geometry;
- безусловную запись данных 2ГИС поверх редакторских данных;
- полноценные offline-карты и turn-by-turn до проверки лицензии, размера
  пакетов, обновления карт и privacy review;
- новый LLM/RAG только ради видимости «умного» продукта.

## 2. 2ГИС: ключи, сервисы и квоты

### 2.1 Тип ключа

Официальная документация 2ГИС сообщает: demo key создаётся один раз и
действует один месяц; demo key не предназначен для Mobile SDK. Для SDK нужен
отдельный ключ в активной подписке. Если у ключа задан App ID, он предназначен
только для SDK; для прямых HTTP-запросов нужен отдельный HTTP key.

Источники: [access keys](https://docs.2gis.com/en/platform-manager/subscription/keys),
[key management](https://docs.2gis.com/en/platform-manager/subscription/managing-keys),
[Routing API overview](https://docs.2gis.com/en/api/navigation/routing/overview).

В backend используем только:

```env
ROUTING_PROVIDER=2gis
TWO_GIS_HTTP_API_KEY=<server-secret>
TWO_GIS_ROUTING_BASE_URL=https://routing.api.2gis.com
ROUTING_TIMEOUT_SECONDS=10
TWO_GIS_ROUTING_ALTERNATIVE=0
TWO_GIS_ROUTING_FILTERS=dirt_road,ferry
```

Фактическое имя переменной в окружении должно быть приведено к этому
контракту либо явно смэплено в deployment secret. Значение ключа никогда не
попадает в Git, логи, analytics, crash reports, mobile build args, fixture или
ответ API.

### 2.2 Что видно на выданном demo-экране

Ниже приведены значения со скриншота пользователя (период **28.08.2026–
28.09.2026**). Это рабочая подсказка для budget guard, а не замена данным
Platform Manager: перед smoke и production сверяем фактический portal.

| Сервис | Лимит на экране | Решение |
| --- | ---: | --- |
| Places API | 1 000 | сейчас — enrichment/reconciliation небольшими батчами |
| Suggest API | 1 000 | не использовать для фонового полного импорта |
| Static API | 30 000 | позже — share/preview, не источник маршрутов |
| Truck Directions API | 1 000 | не нужен туристическому MVP |
| Distance Matrix API | 1 000 | следующий этап для ETA/порядка остановок |
| TSP API | 1 000 | следующий этап для оптимизации порядка, не слепой сортировки |
| Isochrone API | 1 000 | исследование зон доступности после базового каталога |
| Map Matching API | 1 000 | только для opt-in GPS/записанного трека |
| Directions API | 1 000 | SDK-only; не путать с HTTP Routing API |
| Map Tiles API | 500 000 | только после subscription/licence и mobile architecture decision |
| Geocoder API | 1 000 | обратное геокодирование и проверка адресов |
| Categories API | 1 000 | маппинг рубрик, не публикация без review |
| Regions API | 1 000 | границы/районы и административная нормализация |
| Markers API | 1 000 | точечные объекты/поиск, не bulk crawler |
| Radar API | 1 000 | только после отдельного location consent |
| Routing API | 1 000 | основной test-contour provider |
| Raster Tiles API | 30 000 | fallback/preview, не постоянная offline-карта |
| MapGL JS API | без лимита на экране | web-only; к Flutter native не переносим автоматически |

Budget policy:

1. У каждого batch job есть `max_requests`, rate limit, dry-run и checkpoint.
2. При 80% лимита job останавливается без частичного auto-publish и создаёт
   alert.
3. Ошибка 429 не ретраится бесконечно; используется bounded backoff и
   circuit breaker.
4. Usage metric содержит service/key alias, но не сам ключ.
5. Demo period и остаток квоты хранятся в ops secret/registry, а не в
   пользовательском UI.

### 2.3 Выбор сервиса по этапам

```text
Сейчас: Routing + Geocoder/Places для точечных проверок
  ↓
Следом: Distance Matrix/TSP для порядка и ETA
  ↓
После каталога: Categories/Regions, isochrone, map matching
  ↓
Отдельное решение: Mobile SDK / offline territories / native navigator
```

2GIS Routing API для одного набора ordered points поддерживает до 5 точек для
пешеходного маршрута и до 10 для остальных режимов; demo key ограничивает
максимальную длину маршрута 50 км. Эти ограничения должны быть проверены до
сетевого вызова и отражены в error contract. См. [routing reference](https://docs.2gis.com/en/api/navigation/routing/reference/routing).

## 3. Канонический контракт маршрута

### 3.1 Время

В API и UI никогда не смешиваем:

| Поле | Как вычисляется | Что видит пользователь |
| --- | --- | --- |
| `movement_duration_seconds` | время движения по graph provider | «В пути» |
| `visit_duration_minutes` | сумма рекомендованного времени остановок | «На остановках» |
| `transfer_duration_seconds` | ожидание/пересадки для public/mixed | «Пересадки» |
| `buffer_duration_seconds` | резерв на вход, отдых и неопределённость | «Запас» |
| `total_duration_seconds` | сумма компонентов | «Всего примерно …» |

Если один компонент неизвестен, он не подменяется фиктивными 45 минутами без
пометки. Старый `haversine × 1.35` допускается только для local/test и должен
иметь `synthetic=true`.

### 3.2 Дороги, тропы и транспорт

Минимальный внутренний mapping:

| КрымТрип | 2ГИС | Правило |
| --- | --- | --- |
| `walk` | `walking` | pedestrian graph, stairs/grade/water warnings |
| `car` | `driving` | road graph, traffic mode, closed roads false |
| `bicycle` | `bicycle` | включается отдельным флагом после fixtures |
| `public` | `/public_transport/2.0` | отдельный adapter с расписанием |
| `mixed` | ordered legs | каждая leg имеет собственный mode/transfer |

Quality gate MUST проверять:

- начало/конец geometry и порядок `lon,lat`;
- finite coordinates, SRID 4326 и отсутствие пустой линии;
- соответствие mode заявленному транспорту;
- waterway/ford/ferry/bridge и protected/private/restricted areas;
- `surface`, `smoothness`, `tracktype`, `sac_scale`, stairs и crossings, если
  они доступны из OSM/editorial/provider;
- набор высоты, максимальный уклон и экспозицию для walking/bicycle;
- максимальную длину leg/total и demo 50 km;
- наличие актуального доступа и сезонных ограничений;
- ratio geometry length / provider distance, чтобы поймать испорченный WKT.

Исключённый тип дороги может вернуться, если без него провайдер не может
построить путь. Поэтому `filters` — не достаточное доказательство: результат
получает structured warning и проходит собственную проверку.

### 3.3 Статусы качества

```text
unverified → checking → verified
                       ↘ verified_with_warnings
                       ↘ needs_review → unusable
```

- `verified`: можно показывать и предлагать;
- `verified_with_warnings`: показывать с предупреждением и подтверждением;
- `needs_review`: только редактору/ограниченной выдаче;
- `unusable`: не публиковать;
- `unverified`: draft only.

Отсутствие terrain/access данных означает `unknown`, а не `easy` или
`suitable`.

## 4. Обновление каталога через API 2ГИС

### 4.1 Зачем и что обновляем

2ГИС полезен для проверки названия, координат, адреса, рубрик, расписания,
внешнего идентификатора и freshness. Он не является автоматическим редактором
нашего туристического контента и не заменяет OSM, editorial facts или ручную
проверку опасных троп.

Safe precedence:

```text
manual/editorial override
  > verified local/OSM facts
  > 2GIS current observation
  > generated suggestion
```

Автоматически можно обновлять только пустые/технические поля или создавать
предложение на review. Координаты и название опубликованной точки нельзя
перезаписывать при одном приблизительном совпадении.

### 4.2 Два режима job

**Dry-run (обязательный первый запуск):**

1. выбирает bounded batch (например, 50–100 мест);
2. ищет 2ГИС по `q + location + radius` или стабильному external id;
3. считает match confidence по расстоянию, normalized name, locality и
   category;
4. пишет sanitized JSON report: `matched`, `ambiguous`, `not_found`,
   `quota_stop`, без ключа и лишних PII;
5. не меняет `publication_status` и не публикует ничего.

**Apply после review:**

- обновляет только разрешённые поля;
- пишет `source_payload["two_gis"]` с `provider_id`, `fetched_at`, API
  version, fields и confidence;
- обновляет `source_checked_at`/`freshness_status`;
- создаёт audit record и оставляет старое значение при конфликте;
- переводит неоднозначные записи в `needs_review`.

### 4.3 Поля и ограничения

| Поле | Авто-apply | Условие |
| --- | --- | --- |
| `source_external_id` | да | только если отсутствует и match high-confidence |
| `location` | только proposal | расстояние выше порога требует review |
| `address` | да | не затирать editorial override |
| `opening_hours_raw`/schedule | proposal | расписание имеет timezone и observed_at |
| `name`/description | proposal | редактор подтверждает локализацию и туристический смысл |
| categories/rubrics | proposal | маппинг 2ГИС → наша taxonomy versioned |
| photos | нет в этом job | лицензия/attribution и отдельный media pipeline |
| `safety_warnings` | нет | только editorial/OSM/manual evidence |

Нужно реализовать `scripts/enrich_places_2gis.py` по образцу OSM importer:
`--limit`, `--only-missing`, `--output`, `--cache-dir`, `--apply` и
`--max-requests`. Apply без отчёта и без явного флага запрещён.

### 4.4 Расписание

`host cron` запускает refresh только для stale records, например:

```text
каждые 6 часов: opening-hours/availability proposals
ежедневно: freshness/reconciliation batch
еженедельно: full catalog audit + duplicate report
```

Падение внешнего API не делает место закрытым и не удаляет данные; ставится
`freshness_status=stale` и показывается «проверьте перед поездкой».

## 5. Персонализация и рекомендации

### 5.1 UX prompt

После первого успешного API-входа и загрузки `/me`:

1. если `preferences_updated_at` отсутствует, показать один bottom sheet;
2. объяснить пользу и разнообразие («не запираем ленту в одной теме»);
3. CTA ведёт на `/settings/account/preferences`;
4. «Позже» скрывает приглашение до следующей authenticated session;
5. ошибка сети не блокирует home;
6. local/mock не показывает prompt автоматически;
7. после сохранения invalidate profile/recommendation providers.

### 5.2 Текущие и будущие сигналы

Порядок силы:

```text
quality/publication/availability (hard gate)
→ explicit preferences (strong prior)
→ current request (strongest intent)
→ kids/pets/accessibility constraints
→ favorite/start/complete
→ meaningful_view (weak, decayed)
→ skip cooldown
→ season/freshness/coarse region
→ exploration/diversity
```

Просмотр карточки никогда не меняет профиль и не может один сформировать
filter bubble. Начальные policy values:

| Policy | Start value | Guardrail |
| --- | ---: | --- |
| explicit preference contribution | 8–12% rank score | current request wins |
| same category in one deck | max 40% | at least 2 categories when available |
| same region in one deck | max 60% | explore nearby alternatives |
| meaningful-view decay | 14 days | favorite/start/complete stronger |
| skip cooldown | 14 days | user can undo/reset |
| exploration slots | 20–30% | only quality-approved routes |
| repeated route | no sooner than 30 days | except explicit revisit |

Ranker v1 сначала deterministic и explainable:

```text
score = quality_gate
      × (0.45 current_intent
         + 0.20 explicit_preferences
         + 0.15 context
         + 0.10 positive_behavior
         + 0.10 exploration)
      − cooldown_penalty
```

Коэффициенты — конфигурация и версия, а не магические константы в UI. Каждая
карточка получает `explanation_code` (например, `matches_interest`,
`nearby_exploration`, `fresh_route`) и кнопку «Почему это?». Пользователь может
очистить preferences, скрыть тему или отключить персонализацию.

### 5.3 AI подбор

AI не ранжирует непроверенные точки напрямую. Он:

1. извлекает intent в нормализованный DTO;
2. вызывает allowlisted search/match tools;
3. получает только quality-approved candidates и freshness fields;
4. предлагает 2–3 разнообразных варианта;
5. объясняет ограничения и источник времени/расстояния;
6. не записывает preferences без явного подтверждения.

Offline/ошибка AI использует deterministic matcher; ответ «не знаю» лучше
выдуманного моста через реку.

## 6. Offline-first без ложного обещания

### 6.1 Уровни

| Уровень | Содержимое | Статус |
| --- | --- | --- |
| L0 | offline login shell + last-known profile | следующий backend/mobile contract |
| L1 | полный read-only route snapshot + stops + cached media | первый mobile slice уже есть |
| L2 | active execution snapshot + idempotent outbox | после execution mobile |
| L3 | map tiles/places/routing territories 2ГИС | только после SDK/offline license decision |

L1 не называется «офлайн-навигацией»: это открытие сохранённого маршрута без
сети. В карточке видны дата snapshot, provider и stale warning.

### 6.2 Хранилище и безопасность

- refresh token только в secure storage;
- route JSON — versioned namespace, schema migration и bounded size;
- обложки/медиа — disk cache с trusted-origin allowlist;
- очистка одной копии, всех копий и автоматическая очистка при logout;
- будущий namespace `account_id`, чтобы безопасно хранить несколько аккаунтов;
- encrypted database/file container — перед L2, если snapshots содержат
  приватные user-created маршруты;
- не отправлять offline payload в analytics/crash logs.

### 6.3 Offline login

Разрешённый сценарий:

1. ранее успешно вошедший пользователь открывает приложение без сети;
2. локальная сессия имеет bounded grace period и refresh metadata;
3. показываем «Офлайн-сеанс» и только разрешённые cached screens;
4. новые server mutations блокируются или ставятся в outbox;
5. при появлении сети refresh/reconcile выполняется idempotently;
6. после expiry grace period требуется сеть и повторный вход.

Нельзя считать наличие старого access token бессрочной авторизацией.

## 7. Переход в 2ГИС и Apple surfaces

### 7.1 Hand-off в приложение 2ГИС

Реализуем после проверки официальной схемы deep link и лицензии:

- backend/mobile формирует только публичные координаты/названия остановок;
- сначала пробуем universal link, затем app scheme через OS capability check;
- если 2ГИС не установлен, открываем web fallback;
- перед hand-off показываем, какие точки будут переданы;
- не передаём токены, профиль, историю и точную live location без consent;
- аналитика фиксирует `handoff_attempt/result`, но не URL с приватными
  параметрами.

Нельзя угадывать undocumented scheme в production. Нужны vendor-confirmed
examples, iOS/Android device smoke и rollback flag `two_gis_handoff_enabled`.

### 7.2 Нативный SDK

Для карты внутри приложения рассматриваем 2GIS Full SDK (map + routing +
navigator + offline) или provider-neutral map bridge. Full и Map SDK нельзя
подключать одновременно. SDK key/App ID и HTTP key — разные secrets. Решение
принимается после ответа 2ГИС по subscription, attribution, размеру binary,
offline territories и условиям кэширования. Источники: [Android SDK](https://docs.2gis.com/en/android/sdk/overview),
[iOS SDK](https://docs.2gis.com/en/ios/sdk/start), [navigation](https://docs.2gis.com/en/ios/sdk/examples/navigation).

### 7.3 WidgetKit и Dynamic Island

Это отдельный read-only presentation layer, не место для API keys и тяжёлой
логики:

1. приложение пишет в App Group только минимальный execution snapshot:
   route title, next stop, progress, ETA bucket, updated_at;
2. WidgetKit читает snapshot и показывает stale state, если он старше TTL;
3. Live Activity/Dynamic Island включается только для active execution и
   явного opt-in;
4. кнопка ведёт deep link обратно в Active Route;
5. completion/cancel меняют snapshot атомарно;
6. sensitive route names можно скрыть на lock screen настройкой пользователя;
7. Android аналог (notification/ongoing card) планируется отдельно.

Acceptance: widget никогда не показывает live GPS или секрет, переживает
перезапуск, корректно очищается при logout и не ломает приложение без
поддержки Live Activities.

## 8. Workstreams и порядок выполнения

| ID | Приоритет | Репозиторий | Результат | Зависимость |
| --- | --- | --- | --- | --- |
| GIS-01 | P0 | backend/platform | canonical HTTP key, expiry/quota registry, redaction | сразу |
| GIS-02 | P0 | backend | adapter contract tests + real-key smoke | GIS-01 |
| GIS-03 | P0 | backend/platform | provider-result + stop-data + region road-event quality gate v1 сделаны; full terrain/access gate остаётся | GIS-02 |
| GIS-04 | P1 | backend | geometry/routing/freshness/time/warnings, append-only revision snapshot linkage, DB mutation trigger и bounded retention cleanup сделаны; scheduling/alerts остаются | GIS-03 |
| GIS-05 | P1 | mobile | provider geometry projection + quality notice сделаны; real map/attribution/Active Route остаются | GIS-04 |
| GIS-06 | P1 | backend | safe 2GIS catalog dry-run/reconciliation | GIS-01 |
| GIS-07 | P1 | backend/platform | scheduled stale refresh + quota alerts | GIS-06 |
| PREF-01 | P0 | mobile | prompt + lightweight quiz | current API (done first slice) |
| PREF-02 | P0 | backend | bounded preferences scoring (done first slice) | PREF-01 |
| RECO-01 | P1 | backend | feedback/deck tables and deterministic ranker | GIS-03 |
| RECO-02 | P1 | mobile | deck, explanations, skip/reset/opt-out | RECO-01 |
| AI-01 | P1 | backend | AI intent → approved candidates only | GIS-03, RECO-01 |
| OFF-01 | P0 | mobile | L1 route snapshots/list/clear (done first slice) | current route detail |
| OFF-02 | P1 | backend+mobile | L0 offline session and L2 execution outbox | execution API |
| OFF-03 | P2 | mobile/platform | 2GIS territory/map offline | SDK/license decision |
| HAND-01 | P1 | mobile | vendor-confirmed 2GIS hand-off + web fallback | vendor docs |
| APPLE-01 | P2 | mobile | WidgetKit/App Group snapshot | active execution |
| APPLE-02 | P2 | mobile | Live Activity/Dynamic Island | APPLE-01, privacy review |

### Рекомендуемый спринтовый порядок

**Sprint A — локальный срез выполнен:** GIS-01/02 без real-key smoke,
PREF-01/02, OFF-01, provider-result часть GIS-03, GIS-04 и mobile geometry
projection/quality notice.  
**Sprint B — следующий:** full independent terrain/water/access gate, GIS-06,
retention scheduling/alerts и quality/admin review.  
**Sprint C:** GIS-05, mobile Active Route, L2 outbox, RECO-01.  
**Sprint D:** RECO-02, AI-01, scheduled enrichment and quota dashboards.  
**Sprint E:** vendor hand-off, SDK spike, WidgetKit/Live Activity decision.

## 9. Definition of Done

### Backend/data

- [ ] HTTP key type/expiry/terms recorded without value;
- [x] adapter has timeout, typed errors, key redaction and response tests;
- [ ] 2GIS smoke executed against test contour with quota checkpoint;
- [x] application-level append-only routing snapshot is linked to execution;
- [x] DB-level snapshot mutation guard и bounded retention cleanup enabled;
- [x] provider-result gate rejects missing geometry, invalid legs, pedestrian
  highway contradiction and extreme slope; flags pace/gain/dirt/ferry risks;
- [x] provider + stop-data + region road-event quality gate v1 is active;
- [ ] full geometry/terrain/water/access/availability gate active;
- [x] RouteDetail exposes provider geometry, source/freshness, time breakdown,
  elevations, quality status and warnings;
- [ ] catalog enrichment starts dry-run, stores provenance and never auto-publishes;
- [x] explicit preferences affect ranking softly and explainably;
- [ ] deck feedback, decay, caps and exploration pass property fixtures;
- [ ] AI sees only approved candidate DTOs.

### Mobile

- [x] prompt opens only for incomplete API preferences and has a later path;
- [x] preference screen is lightweight, accessible and resettable;
- [x] route snapshot can be saved, opened without network and removed;
- [x] logout removes local account content;
- [x] route detail projects provider geometry and explains quality status;
- [ ] Active Route starts/resumes/updates against execution API;
- [ ] map renders verified provider geometry with attribution;
- [ ] offline state is explicit and does not claim turn-by-turn;
- [ ] 2GIS hand-off has documented fallback and device smoke;
- [ ] widgets/Live Activity show only minimal stale-safe snapshot.

### Release gates

- backend `validate.sh` green;
- mobile format/analyze/test/goldens green;
- contract fixtures cover malformed provider JSON, 429, timeout, water/grade
  edge cases and old clients;
- security check confirms no key in bundle/logs/analytics;
- quota budget and rollback flag tested;
- production rollout starts with `ROUTING_PROVIDER=stub` or disabled cohort and
  switches to 2ГИС only after quality smoke;
- progress/blueprint/ADR statuses agree.

## 10. Risks and rollback

| Риск | Защита | Rollback |
| --- | --- | --- |
| demo quota/expiry | budget guard, alert, cache, bounded jobs | disable provider, keep last verified snapshots |
| graph route crosses unsafe terrain | own quality gate + editorial review | mark `needs_review`, hide from public |
| key type mismatch | separate HTTP/SDK secrets and preflight | revert feature flag, no mobile key |
| stale opening hours | observed/expiry fields and warning | show stale, never claim open |
| personalization filter bubble | caps, decay, exploration, reset | disable ranker, serve catalog order |
| offline data leak | clear on logout, future account namespace/encryption | disable offline save and wipe namespace |
| widget stale/private content | TTL, lock-screen setting, atomic clear | disable widget/live activity |
| vendor outage | timeout/circuit breaker and synthetic only in local | use last verified route or honest error |

## 11. Следующая конкретная очередь задач агенту

1. Зафиксировать фактический тип/срок HTTP key в private ops registry.
2. Выполнить sanitized two-point smoke `walking` и `driving`; сохранить только
   response fixture без query key.
3. Подключить расписание retention job и мониторинг попыток mutation для уже
   реализованного `route_routing_snapshots`; revision связан с
   `RouteExecution`, DB-level mutation guard и bounded cleanup уже включены.
4. Расширить gate независимыми OSM/editorial water, access, surface, closure и
   season checks; provider + stop-data + region road-event v1 уже работает,
   но не сертифицирует тропу.
5. Реализовать dry-run `enrich_places_2gis.py`, затем проверить 20 точек вручную.
6. Реализовать Active Route/resume и L2 outbox; provider geometry уже
   подключена к текущему preview.
7. Добавить recommendation deck/feedback с diversity property tests.
8. После vendor confirmation реализовать hand-off; отдельно принять решение по
   Full SDK/offline territories.
9. Только после execution API — WidgetKit/Dynamic Island.

Пока эти пункты не закрыты, продукт может честно показывать каталог и
сохранённые snapshots, но не должен обещать полноценного автономного
навигатора.
