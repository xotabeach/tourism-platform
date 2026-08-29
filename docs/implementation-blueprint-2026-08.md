# КрымТрип — единый blueprint реализации

Дата версии: **2026-08-28**  
Статус: **proposed canonical execution plan**  
Владелец: product + backend + mobile + platform

Этот документ переводит продуктовые намерения в исполнимую спецификацию для
следующего большого инкремента: реальные карты и маршрутизация 2ГИС,
честное прохождение маршрута, персональные рекомендации и использование
пользовательских предпочтений.

Новые product-facing требования (prompt, расширенные preferences, L0–L3
offline, безопасное обновление каталога, hand-off в 2ГИС и Apple surfaces)
собраны в [расширенном плане 2ГИС/персонализации/offline](2gis-personalization-offline-plan-2026-08-28.md).

Он не заменяет исторические ревью и специализированные документы. Он
связывает их и задаёт порядок, в котором работу можно безопасно отдавать
агенту или разработчику.

## 0. Как пользоваться документом

### Иерархия источников истины

При конфликте документов используем такой порядок:

1. фактический код, миграции и green validation;
2. [живой progress](progress.md);
3. этот blueprint и [implementation plan](implementation-plan.md);
4. специализированные ADR/design/security docs;
5. исторические review-документы.

Исторический документ не переписываем задним числом. Если код изменил
решение, обновляем blueprint, progress и changelog.

### Язык требований

В этом документе:

- **MUST / ОБЯЗАН** — release-blocking invariant;
- **SHOULD / СЛЕДУЕТ** — default, отступление требует записи в ADR или issue;
- **MAY / МОЖНО** — опциональная реализация без нарушения контракта.

Каждая work item должна иметь ID, owner, repository, входной контракт, output,
security/privacy impact, тесты, метрики, rollback и Definition of Done.

### Что этот blueprint не обещает

- это не сертификат OWASP, не юридическое заключение и не гарантия полевой
  безопасности;
- наличие ответа 2ГИС не означает, что каждая тропа безопасна, открыта или
  подходит конкретному туристу;
- demo API key не означает разрешение использовать Mobile SDK в production;
- ML, embeddings, live GPS и offline navigator не должны появиться только
  потому, что они красиво звучат в презентации.

## 1. Краткий результат, к которому идём

Пользователь должен получить честный и понятный цикл:

```text
профиль и контекст
      ↓
разнообразная подборка маршрутов
      ↓
карточка с реальными временем/дистанцией/сложностью/доступностью
      ↓
проверенный маршрут и карта
      ↓
старт прохождения → остановки → пауза/возобновление
      ↓
завершение с прозрачным подтверждением
      ↓
история, обратная связь, rewards
      ↓
следующая подборка, не запирающая в одной теме
```

### Обещание продукта

> «Мы предлагаем маршрут, который соответствует вашим предпочтениям,
> показываем, почему он вам подходит, честно сообщаем ограничения и не
> называем прямую линию дорогой. Если маршрут нельзя подтвердить — мы прямо
> скажем об этом».

### Основные продуктовые метрики

Метрики не являются единственным критерием качества, но помогают не принять
красивый UI за полезный продукт:

| Цель | Метрика | Guardrail |
| --- | --- | --- |
| Найти подходящий маршрут | detail-open → start conversion | не ухудшать error/empty rate |
| Дать реализуемый путь | % public routes с `quality_status=verified` | 0 public synthetic без явной маркировки |
| Довести до результата | start → first stop → completion | completion не стимулировать ложным reward |
| Персонализировать | explicit preference match | не уменьшать catalog coverage ниже порога |
| Сохранить разнообразие | category/region entropy, unique categories per deck | caps и exploration обязательны |
| Не раздражать | skip/repeat/complaint rate | один просмотр не меняет профиль |
| Надёжно работать | API availability, p95 latency | vendor failure не ломает catalog |

## 2. Фактическая точка старта

### Backend as-built

- FastAPI modular monolith, SQLAlchemy async, PostgreSQL/PostGIS, Redis,
  Alembic и typed Pydantic schemas.
- `RoutingProvider` находится в
  `tourism-backend/src/tourism_backend/modules/route_builder/application/routing.py`.
- В коде есть `stub` для local/test и первый `2gis` HTTP adapter с typed
  settings, detailed WKT, road filters и altitude normalization. Provider-result
  gate v1 проверяет geometry/legs, mode/road contradictions, уклон и набор
  высоты. По умолчанию feature flag остаётся `stub`; synthetic результат не
  считается готовой навигацией.
- `Route` уже содержит базовые поля `distance_meters`,
  `estimated_duration_minutes`, `difficulty`, `transport_mode`,
  `seasonality`, `accessibility`, `geometry`.
- `RouteExecution` и API v0 уже реализованы: ownership/BOLA, snapshots
  stops, active/completed/cancelled, idempotent start/complete/cancel,
  pagination.
- `/me/preferences` уже сохраняет четыре поля:
  `preferred_categories`, `preferred_difficulty`, `travels_with_kids`,
  `travels_with_pets`.
- Первый bounded preference signal уже подключён к match/generate scoring и не
  меняет профиль пользователя. Recommendation tables, deck, feedback endpoint,
  diversity reranker и cron ещё не реализованы.

### Mobile as-built

- Flutter + Riverpod, repository/data-source abstraction, Dio, secure refresh
  storage и environment guard.
- Local mock разрешён только в local; test/staging/production должны ходить в
  API.
- Route catalog и detail существуют; swipe deck уже конечный и исключает
  избранные маршруты на клиенте.
- Добавлены L1 read-only route snapshots, список/удаление offline-копий и
  очистка их при logout; кнопка «Пройти маршрут» всё ещё требует полного
  API-backed journey.
- Для API-пользователя добавлен одноразовый personalization prompt и лёгкий
  quiz с reset/clear; mock contour намеренно не показывает prompt.
- Нативный 2ГИС Mobile SDK не подключён; текущий server key нельзя считать SDK
  key.

### Platform/docs as-built

- Есть `implementation-plan.md`, `progress.md`, ADR-004/009, route
  intelligence roadmap, swipe recommendations, security baseline и deploy
  runbook.
- До этого blueprint не хватало единой трассировки «user story → API → data →
  screen → tests → release gate».

### Vendor facts, влияющие на план

Согласно документации 2ГИС:

- demo key бесплатен, действует один месяц и предназначен для HTTP API;
- demo key не работает с Mobile SDK;
- SDK требует отдельной subscription key; App ID ограничивает область её
  использования;
- cloud Routing API использует `/routing/7.0.0/global` и поддерживает
  транспортные режимы, detailed geometry, filters, exclusions, alternatives и
  altitude data;
- demo routing ограничен максимальной длиной 50 км;
- при невозможности соблюсти исключённый тип дороги провайдер может вернуть
  участок с ним, поэтому ответ нужно дополнительно проверять.

Ссылки: [2ГИС access keys](https://docs.2gis.com/en/platform-manager/subscription/keys),
[Routing API overview](https://docs.2gis.com/en/api/navigation/routing/overview),
[routing reference](https://docs.2gis.com/en/api/navigation/routing/reference/routing).

## 3. Границы релиза

### Release R-next (обязательный срез)

1. Server-side 2ГИС Routing API в test contour.
2. Нормализованный route snapshot с provider, freshness, duration, distance,
   geometry, warnings и quality status.
3. Quality gate против прямых линий, неподходящего транспорта, воды,
   недоступных дорог, экстремального уклона и устаревших объектов.
4. Mobile Route detail и Active Route с картой, остановками, прогрессом,
   ошибками, resume и ручным completion v0.
5. Backend recommendation deck, читающий explicit preferences и bounded
   behavioural signals.
6. Diversity/exploration policy и explainability.
7. Test/observability/security/release gates.

### После R-next

- native 2ГИС Mobile SDK после отдельного license/subscription decision;
- GPS proximity verification — только opt-in и отдельный privacy review;
- weather/opening-hours dynamic reranking;
- OSRM self-host fallback или второй provider;
- rewards/achievements после verified completion;
- controlled experiments и ranker tuning.

### Не входит в этот релиз

- turn-by-turn навигация уровня отдельного навигатора;
- непрерывный background GPS и полная история перемещений;
- offline map packs;
- billing/Travel+ monetization;
- микросервисы, Kafka, Kubernetes, Qdrant и production RAG;
- обещание, что vendor graph покрывает каждую горную тропу.

## 4. Архитектура и границы ответственности

```text
┌──────────────────────────────┐
│ Flutter mobile               │
│ catalog / detail / execution │
│ recommendations / settings   │
└──────────────┬───────────────┘
               │ HTTPS, versioned DTOs
┌──────────────▼───────────────┐
│ КрымТрип API                 │
│ route-builder               │
│ routing adapter + quality   │
│ route execution             │
│ recommendation ranker      │
└───────┬──────────┬───────────┘
        │          │
   Postgres/    Redis/cache
   PostGIS      locks/limits
        │
┌───────▼──────────────────────┐
│ External providers           │
│ 2GIS HTTP Routing API        │
│ (later: SDK / OSRM / weather)│
└──────────────────────────────┘
```

### Обязательные границы

- Application layer не знает URL, query `key` и JSON-форму 2ГИС.
- Mobile не вызывает 2ГИС HTTP Routing API напрямую.
- Vendor key не входит в API response, crash report, analytics или bundle.
- Recommendation ranker не меняет profile preferences.
- Route execution использует immutable routing snapshot; изменение внешнего
  графа не переписывает уже начатое прохождение.
- Quality gate находится до публикации и до рекомендации, а не только внутри
  UI.

### Конфигурация

```env
APP_ENV=test|staging|production
ROUTING_PROVIDER=stub|2gis
TWO_GIS_ROUTING_BASE_URL=https://routing.api.2gis.com
TWO_GIS_HTTP_API_KEY=<secret>
ROUTING_TIMEOUT_SECONDS=8
TWO_GIS_ROUTING_ALTERNATIVE=0
TWO_GIS_ROUTING_FILTERS=dirt_road,ferry
TWO_GIS_MAX_ROUTE_METERS=50000
ROUTE_QUALITY_POLICY_VERSION=v1
RECOMMENDER_ENABLED=false
RECOMMENDER_RANKER_VERSION=v1
```

`stub` разрешён только local/test или явно обозначенным draft. Production
startup должен fail closed, если выбран `2gis`, но key отсутствует.

## 5. Каноническая модель маршрута

### 5.1 Разделяем четыре вида времени

Нельзя показывать одно число как «время маршрута» без расшифровки:

| Поле | Смысл |
| --- | --- |
| `movement_duration` | время движения между точками по графу |
| `visit_duration` | рекомендованное время на остановках |
| `transfer_duration` | пересадки/ожидание для mixed/public |
| `buffer_duration` | резерв на поиск входа, отдых, неопределённость |
| `total_duration` | сумма, показываемая в карточке с breakdown |

`total_duration` MUST быть вычислимым и объяснимым. Значение из старого
`haversine × 1.35` нельзя выдавать как movement time.

### 5.2 Транспортная taxonomy

Внутренний API использует стабильные значения:

```text
walk       — пешком
car        — автомобиль
bicycle    — велосипед (после отдельного enable)
public     — общественный транспорт
mixed      — составной маршрут
```

Маппинг 2ГИС:

```text
walk → walking
car → driving
bicycle → bicycle
public → /public_transport/2.0
mixed → ordered legs with explicit transfer metadata
```

Синонимы `car/pedestrian` из старых примеров 2ГИС не должны проникать в
публичный контракт.

### 5.3 Difficulty taxonomy

Публичные labels: `easy`, `moderate`, `hard`, `unknown`. Внутренне храним
числовые компоненты и confidence:

```text
difficulty_score =
  distance_component
  + elevation_gain_component
  + max_grade_component
  + surface/technical_component
  + duration_component
  + exposure/water-crossing penalties
```

Правила:

- расстояние само по себе не определяет сложность;
- набор высоты и максимальный уклон обязательны для walking/bicycle,
  если данные доступны;
- неизвестные terrain fields не превращаются в «easy»;
- `unknown` допустим для draft, но требует warning в public detail;
- mapping к preference `easy|moderate|hard` версионируется;
- редактор может подтвердить/исправить difficulty только с audit trail.

### 5.4 Accessibility и пригодность

JSONB `accessibility` должен постепенно перейти к версионированной схеме:

```json
{
  "wheelchair": "unknown|not_suitable|partial|suitable",
  "stroller": "unknown|not_suitable|partial|suitable",
  "children": "unknown|not_recommended|suitable",
  "pets": "unknown|forbidden|conditional|allowed",
  "stairs": true,
  "steep_sections": true,
  "water_crossings": 0,
  "mobile_signal": "unknown|intermittent|reliable",
  "source": "editorial|provider|osm|manual",
  "verified_at": "timestamp"
}
```

`unknown` не равен `false`. Для children/pets preference отсутствие данных
означает «предупредить/не утверждать», а не автоматически исключить всё.

### 5.5 Availability

Доступность — отдельная сущность, а не декоративная строка:

- `route_status`: open / seasonal / temporarily_closed / unknown;
- stop opening hours с timezone региона;
- date interval и recurring weekly schedule;
- weather dependency и hazard advisory;
- source, observed_at, expires_at, confidence;
- manual override с author/audit.

Нельзя строить маршрут через музей, закрытый в выбранное время, и показывать
его как полностью доступный. Если расписание не подтверждено, карточка говорит
«проверьте перед поездкой», а ranker снижает confidence.

## 6. 2ГИС adapter и routing pipeline

### 6.1 Preflight перед кодом

- [ ] Проверить в Platform Manager, что добавленный ключ — HTTP API key, а не SDK/App ID key.
- [ ] Зафиксировать дату создания demo key и дату истечения.
- [ ] Уточнить включённые сервисы, quota, rate limit и production terms.
- [ ] Настроить IP/header restrictions, если доступны для типа key.
- [ ] Сохранить key только в secret storage; не копировать в issue, чат,
  fixture или docs.
- [x] Проверить, что local egress может обратиться к
  `routing.api.2gis.com` (подтверждено sanitized smoke 2026-08-29).
- [ ] Зафиксировать legal/attribution/cache requirements.

Первый adapter и нормализация уже находятся в backend. До включения provider
нужно закрыть оставшиеся preflight-пункты и выполнить sanitized smoke; наличие
кода adapter само по себе не означает, что demo key разрешает production или
Mobile SDK.

### 6.2 Запрос

Для ordered waypoints используем:

```http
POST /routing/7.0.0/global?key=<server-secret>
Content-Type: application/json
```

Минимальное тело после нормализации:

```json
{
  "points": [
    {"type": "walking", "lon": 33.52, "lat": 44.60},
    {"type": "pref", "lon": 33.54, "lat": 44.61}
  ],
  "transport": "walking",
  "route_mode": "fastest",
  "traffic_mode": "jam",
  "output": "detailed",
  "need_altitudes": true,
  "alternative": 1,
  "locale": "ru"
}
```

Точный набор параметров зависит от mode; adapter обязан валидировать его до
сетевого вызова. Для walking вендор ограничивает число points; для demo
учитываем лимит 50 км и не создаём бессмысленные retries.

### 6.3 Filters и exclusions

Фильтры делятся на:

- `soft`: предпочесть избежать, но допускается с warning;
- `hard`: не разрешать; при нарушении — reject/needs_review.

Примеры политики:

| Режим | Default hard/soft policy |
| --- | --- |
| `driving` | не использовать pedestrian-only path; избегать закрытых дорог; dirt/toll — user preference |
| `walking` | не использовать автомагистрали; учитывать stairs/steep/water; закрытые зоны — hard |
| `bicycle` | отдельные фильтры stairway/overpass/car road; slope warning |
| `public` | schedule-aware; transfer count/time visible |

2ГИС может вернуть исключённый тип, если иначе путь не строится. Поэтому
проверяем `filter_road_types`, segment metadata и normalized warnings. Флаг
`allow_locked_roads` по умолчанию false и недоступен обычному пользователю.

### 6.4 Normalization

Adapter преобразует vendor response в доменный `RoutingResult`:

```text
provider = "2gis"
synthetic = false
provider_route_id
legs[]: from/to, geometry, distance, movement_duration, maneuvers
altitude: gain/loss/min/max/max_grade
requested_filters, applied_filters
warnings[]
provider_status
computed_at, expires_at
```

Первый нормализованный API-срез уже отдаёт GeoJSON LineString, provider,
synthetic, quality status/warnings, movement/visit/total time и altitude
metadata. Поля provider route id, maneuvers, immutable revision и expiry
остаются частью snapshot-среза B2.

WKT/geometry parser обязан проверять:

- валидность геометрии и SRID 4326;
- finite coordinates и порядок lon/lat;
- соответствие начала/конца waypoint с допустимой погрешностью;
- отсутствие пустой или двухточечной прямой там, где provider обещал detail;
- разумное соотношение geometry distance к returned distance.

### 6.5 Ошибки

| Provider condition | Domain code | HTTP | User copy policy |
| --- | --- | ---: | --- |
| timeout / 5xx | `routing_provider_unavailable` | 503 | «Маршрут временно недоступен; попробуйте позже» |
| 429/quota | `routing_quota_exceeded` | 429/503 | без раскрытия key/quota internals |
| invalid input | `routing_request_invalid` | 422 | подсветить точку/режим |
| route not found | `route_unavailable` | 422 | объяснить, что путь не подтверждён |
| excluded point | `route_point_excluded` | 422 | предложить изменить stop |
| quality gate fail | `route_quality_rejected` | 422 | warning/review, не прямая линия |

Ответы API используют единый machine-readable Problem Details shape:

```json
{
  "type": "https://api.krymtrip.ru/problems/route-unavailable",
  "title": "Маршрут не подтверждён",
  "status": 422,
  "code": "route_unavailable",
  "detail": "Для выбранного режима не найден проходимый путь",
  "trace_id": "public-correlation-id",
  "details": {"mode": "walking", "point_index": 2}
}
```

`detail` не содержит stack trace, vendor key, внутренних URL или приватные
координаты пользователя.

### 6.6 Cache and freshness

Cache key включает normalized waypoints, mode, filters, date/time bucket,
provider version и policy version. Кэш не должен скрывать закрытие:

- static editorial route geometry — longer TTL, revalidation;
- traffic-sensitive duration — short TTL;
- availability/hazard — own TTL and source freshness;
- cache stampede защищается lock/single-flight;
- при stale response показываем `freshness_status` и warning.

## 7. Route quality gate

### 7.1 Порядок проверки

```text
input validation
  → place/stop access
  → provider route
  → response/schema validation
  → transport/road filters
  → geometry topology
  → terrain/elevation
  → availability/season/weather
  → duration/difficulty calculation
  → quality status
  → persist snapshot
  → publish/recommend/use in execution
```

Проверка выполняется на backend. Mobile только отображает результат и не
может «разрешить» rejected route локальной логикой.

### 7.2 Hard reject conditions

Маршрут MUST быть `unusable` или `needs_review`, если:

- нет двух валидных точек;
- provider status не `OK`;
- point не притянут к допустимому graph;
- режим не соответствует типу транспорта;
- обязательный stop недостижим;
- обнаружен crossing воды/закрытой зоны без подтверждённого bridge/ferry;
- автомобильный route содержит pedestrian-only segment;
- превышены max distance, duration, gain или grade для declared profile;
- requested hard filter нарушен;
- geometry отсутствует, пустая или является неподтверждённой straight line;
- объект закрыт в выбранное время/сезон и нет explicit override.

### 7.3 Soft warnings

`verified_with_warnings` может сообщать о:

- dirt road, stairs, steep section, toll road;
- неполных surface/terrain data;
- сезонной неопределённости;
- intermittent mobile signal;
- неточном opening hours;
- provider fallback или устаревшем snapshot.

Warning должен быть структурированным, локализуемым и видимым до старта.

### 7.4 Необходимая собственная проверка

2ГИС/OSRM покрывает graph routing, но не заменяет editorial safety review.
Для Крыма нужны:

- OSM `surface`, `smoothness`, `tracktype`, `access`, `sac_scale` где есть;
- bridge/ferry/ford/waterway tags;
- protected/private/restricted areas;
- SRTM/altitude profile и max grade;
- seasonal closure/hazard reports;
- manual verification для hard hiking routes;
- source/freshness/confidence на каждом спорном поле.

Если данные неизвестны, продукт не говорит «безопасно». Он говорит «данные
неполные» и выбирает более осторожное действие.

### 7.5 Quality statuses

```text
unverified
  → checking
  → verified
  → verified_with_warnings
  → needs_review
  → unusable
```

Public catalog policy:

- `verified` — обычная выдача;
- `verified_with_warnings` — выдача с предупреждением и подтверждением;
- `needs_review` — только внутренний/editorial режим;
- `unusable` — не публиковать;
- `unverified` — draft only.

## 8. Data model and migration strategy

### 8.1 Routing snapshots

Миграции `0039_route_routing_snapshots` и `0040_snapshot_immutable` добавляют
отдельную append-only таблицу `route_routing_snapshots`, а не перезаписывают
`Route.geometry` при каждом внешнем запросе. `RouteExecution.routing_snapshot_id`
ссылается на запись, созданную при старте:

```text
id UUID PK
route_id UUID FK NULL (SET NULL при удалении родителя)
revision INTEGER
fingerprint VARCHAR(64)
provider VARCHAR
provider_version VARCHAR
transport_mode VARCHAR
geometry GEOGRAPHY(LINESTRING, 4326)
distance_meters INTEGER NULL
movement_duration_seconds INTEGER NULL
visit_duration_minutes INTEGER NULL
transfer_duration_seconds INTEGER NULL
buffer_duration_seconds INTEGER NULL
total_duration_seconds INTEGER NULL
elevation_gain_meters INTEGER NULL
elevation_loss_meters INTEGER NULL
min_altitude_meters INTEGER NULL
max_altitude_meters INTEGER NULL
max_road_angle_degrees REAL NULL
road_types TEXT[] NULL
requested_filters JSONB NULL
warnings TEXT[] NULL
quality_status VARCHAR
quality_policy_version VARCHAR NULL
route_updated_at TIMESTAMPTZ NULL
captured_at TIMESTAMPTZ
created_at TIMESTAMPTZ
```

`revision` увеличивается только при изменении fingerprint (геометрия,
остановки или routing-факты). PostgreSQL trigger запрещает изменение всех
фактов после вставки; допускается только обнуление необязательного `route_id`,
если родитель удаляется. Retention/архивирование — отдельная операционная
политика.

### 8.2 Execution linkage

`RouteExecution` stores `routing_snapshot_id` and user-visible snapshot fields.
An execution must remain reproducible even if route editorial data or vendor
response later changes.

### 8.3 Recommendation data

`route_recommendation_feedback` — append-only, idempotent action events:

```text
user_id, route_id, action, created_at, deck_date,
ranker_version, request_id, source, metadata_minimal
```

Allowed actions: `impression`, `meaningful_view`, `favorite`, `start`,
`complete`, `skip`, optional `hide_category`. Exact GPS and free-form PII are
forbidden.

`route_recommendation_deck_items` — daily materialized deck:

```text
user_id, route_id, deck_date, rank, score,
ranker_version, explanation_code, generated_at
```

Uniqueness and idempotency must prevent duplicate cards after cron retry.

### 8.4 Expand → backfill → switch → cleanup

1. Add nullable columns/tables and dual-read compatibility.
2. Backfill snapshots in bounded batches.
3. Enable feature flag for internal cohort.
4. Verify metrics and quality fixtures.
5. Switch default provider/response only after acceptance.
6. Keep old fields during one compatibility window.
7. Remove dead synthetic/public paths in a separate migration.

Rollback MUST not require destructive downgrade of a migration that has already
been used in production.

## 9. Route execution product and UX

### 9.1 State machine

```text
none ──start──> active ──complete──> completed
                  │  └─cancel──────> cancelled
                  └─resume─────────> active
```

Rules:

- one active execution per user;
- repeated start of the same route is idempotent;
- start of another route returns a conflict with active execution id;
- stop completion is idempotent;
- only owner can read/update execution;
- completion cannot award points until required-stop policy passes;
- cancelled execution never counts as complete.

### 9.2 v0 completion semantics

В v0 нет постоянного GPS. Пользователь вручную подтверждает остановку.
UI честно говорит «Отметить посещение», а не «мы проверили вашу геопозицию».

Варианты будущего подтверждения:

- opt-in proximity check;
- QR/NFC/editorial code;
- photo proof (privacy/legal review);
- manual confirmation with anti-abuse limits.

Нельзя незаметно включать background location ради rewards.

### 9.3 API journey

```text
POST   /api/v1/route-executions
GET    /api/v1/route-executions/active
GET    /api/v1/route-executions/{id}
PUT    /api/v1/route-executions/{id}/stops/{stop_id}/complete
POST   /api/v1/route-executions/{id}/complete
POST   /api/v1/route-executions/{id}/cancel
GET    /api/v1/route-executions?limit=&offset=
```

Start request SHOULD accept an idempotency key in a future compatible header;
current same-route idempotency remains required.

### 9.4 Mobile screen states

Route detail before start:

- карта/preview verified geometry;
- badges: mode, movement time, visit time, total time, distance, difficulty;
- freshness and provider/source;
- accessibility and warnings;
- stops with optional/required marker;
- CTA «Пройти маршрут»;
- if unverified: explanation and disabled/secondary CTA.

Active Route:

- map with polyline and numbered stops;
- current progress (`3 из 7`), next stop and estimated remaining time;
- «Отметить остановку», «Пауза», «Завершить», «Отменить»;
- offline/error banner without losing local intent;
- route warning sheet before entering risky segment;
- resume after app restart/login refresh.

Completion:

- summary of completed/optional/missed stops;
- explicit confirmation before rewards;
- no reward for cancellation;
- history entry with route snapshot date and provider.

### 9.5 Offline and retry behavior

- v0 can cache read-only route snapshot and active execution locally;
- completion actions use an idempotent outbox, bounded retry and conflict
  resolution;
- no silent duplicate POST;
- stale map/route shows timestamp;
- if server cannot verify, UI preserves pending state and says so.

## 10. Recommendation system

Полная спецификация живёт в [ADR-011](decisions/ADR-011-personalized-route-recommendations.md)
и [route-swipe-recommendations.md](route-swipe-recommendations.md). Здесь
зафиксирован implementation contract.

### 10.1 Signal hierarchy

1. publication/quality/availability — hard gate;
2. explicit preferences — strong prior;
3. kids/pets/accessibility — hard или strong soft по выбору пользователя;
4. favorites, starts, completions — positive behavior;
5. meaningful view — слабый bounded signal;
6. skip — конечный cooldown;
7. season, weather, coarse region, freshness — context;
8. exploration/diversity — mandatory reranking.

Обычный просмотр никогда не вызывает `PATCH /me/preferences` и не становится
единственной причиной category lock.

### 10.2 Current preferences mapping

| Stored field | v1 use | Future extension |
| --- | --- | --- |
| `preferred_categories[]` | explicit profile match | weights/primary-secondary interests |
| `preferred_difficulty` | soft difficulty proximity | strict mode/fitness profile |
| `travels_with_kids` | child suitability gate/warning | ages, stroller needs |
| `travels_with_pets` | pet policy gate/warning | leash/size constraints |
| no duration field yet | infer from session/form only | preferred duration bands |
| no region field yet | contextual coarse region | home/base region |

Новые поля добавляются через migration, API schema, quiz UX, privacy note и
ranker fixture одновременно; нельзя silently читать несуществующие поля.

### 10.3 Ranker v1

После hard gates нормализуем признаки 0..1:

```text
score =
    0.30 * explicit_profile_match
  + 0.20 * content_affinity
  + 0.10 * context_fit
  + 0.10 * popularity
  + 0.10 * freshness
  + 0.10 * completion_likelihood
  + 0.10 * exploration_bonus
```

Коэффициенты — `ranker_version`, меняются через review. Behavioural bonus
входит в `content_affinity`/`completion_likelihood` с decay и cap не более
25% итогового score. Сигналы нормализуются, чтобы активные пользователи не
доминировали над новыми.

### 10.4 Diversity/exploration

На candidate pool ≥50 (если каталог позволяет) применяем constrained
reranking:

- не более 40% одной категории;
- не более 50% одного региона;
- ≥20% exploration среди unseen routes;
- не повторять активную карточку;
- не показывать подряд больше двух близких по содержанию маршрутов;
- при малом каталоге честно сообщать, что разнообразие ограничено данными.

Если hard constraints оставили один регион, нельзя подмешивать неподходящий
маршрут только ради красивой статистики.

### 10.5 Cold start и controls

- заполненный quiz → profile prior;
- пустой quiz → editorial/popular/fresh + diversity;
- после первого favorite не перестраивать всё в одну категорию;
- «Почему этот маршрут?» показывает код причины, не скрытую модель;
- «Меньше такого», «Не сейчас», «Сбросить персонализацию» — отдельные
  действия;
- opt-out возвращает editorial/popular deck;
- текущая колода не должна внезапно исчезать после изменения профиля.

### 10.6 Batch and lazy generation

- host cron 03:00 МСК создаёт deck идемпотентно bounded batches;
- новый пользователь получает lazy deck on first request;
- cron lock prevents overlap;
- partial failure leaves previous valid deck and exposes freshness;
- no Celery/Kafka until measured need.

### 10.7 Evaluation

Offline fixtures must cover:

- mountain-heavy history → still receives coast/food/forest exploration;
- kids=true → no route explicitly unsuitable for children;
- pets=true → unknown pet policy warns, not falsely allows;
- hard difficulty → easy/moderate/hard mapping predictable;
- all skips → cooldown expires;
- no profile/no history → useful cold-start deck;
- tiny catalog → no impossible diversity assertion.

Metrics: coverage, diversity, novelty, repeat rate, preference match,
skip/favorite/start/complete, empty rate, p95 generation latency and provider
cost. Release guardrails are defined before tuning weights.

## 11. API contract governance

### 11.1 Public route detail extension

Не ломаем старые clients: добавляем nullable/optional object:

```json
{
  "routing": {
    "provider": "2gis",
    "synthetic": false,
    "quality_status": "verified_with_warnings",
    "transport_mode": "walking",
    "distance_meters": 8420,
    "movement_duration_seconds": 10320,
    "visit_duration_seconds": 5400,
    "total_duration_seconds": 15720,
    "elevation_gain_meters": 310,
    "max_grade_percent": 18.2,
    "freshness_status": "fresh",
    "warnings": ["steep_section"],
    "geometry": {"format": "geojson", "coordinates": []}
  }
}
```

Coordinates in examples are omitted/fixture-only; real API response respects
privacy and licensing policy.

### 11.2 Recommendation endpoints

```text
GET  /api/v1/routes/recommendations/today
POST /api/v1/routes/{route_id}/recommendation-feedback
```

Feedback request:

```json
{
  "action": "skip",
  "deck_date": "2026-08-28",
  "ranker_version": "v1",
  "client_event_id": "uuid"
}
```

Endpoint must be authenticated, owner-scoped, idempotent by
`client_event_id`, and reject arbitrary action names.

### 11.3 Compatibility

- Every new field has a default/nullable migration path.
- OpenAPI output is snapshotted per release.
- CI compares breaking changes and validates examples.
- Mobile fixtures are generated from the same schemas or checked against
  snapshot JSON.
- Deprecated fields have owner, sunset date and migration note.

## 12. Security, privacy and legal controls

### 12.1 Vendor key handling

- HTTP key only in backend secret manager/env;
- SDK keys, if ever needed, are separate restricted keys;
- no key in Git, Docker image layers, logs, analytics, screenshots or mobile
  HTTP headers unless vendor explicitly requires a restricted SDK key;
- rotation runbook and quota alert tested;
- URLs with query `key=` are redacted before logging.

### 12.2 Location privacy

Release R-next does not collect continuous GPS. If proximity validation is
added:

- explicit opt-in with plain-language purpose;
- foreground-first permission;
- minimum precision and shortest retention;
- no location in recommendation events or AI prompts;
- revoke/delete path and privacy policy update;
- abuse/race tests and user-visible pending state.

### 12.3 Security standards target

Target, not claimed certification:

- OWASP ASVS Level 2 for backend/API;
- OWASP MASVS baseline for mobile;
- RFC 9457-style machine-readable API errors;
- OpenAPI 3.1 contract governance;
- threat model update for vendor, map and location boundaries.

Required evidence is a control matrix, not a sentence saying «secure».

### 12.4 Licensing and attribution

Before production:

- record accepted 2ГИС terms and permitted caching/storage;
- define map/route attribution placement in mobile screens;
- confirm use of geometry in public catalog and screenshots;
- confirm separate SDK subscription and App ID policy;
- assign owner for renewal/expiry and incident contact.

## 13. Observability and operations

### 13.1 Structured logs

Allowed fields: `trace_id`, `request_id`, endpoint, provider, mode,
quality_status, status_code, latency_ms, cache_hit, route_points_count,
error_code. Forbidden: API key, tokens, phone, exact user GPS, raw vendor
payload.

### 13.2 Metrics

```text
routing_requests_total{provider,mode,status}
routing_latency_seconds{provider,mode}
routing_quality_rejections_total{reason}
routing_cache_hits_total{provider}
routing_quota_errors_total{provider}
route_execution_started/completed/cancelled_total
recommendation_deck_generation_total{result}
recommendation_diversity_score
recommendation_empty_total
```

### 13.3 Initial SLO proposals

Values are starting targets and must be validated against test-contour data:

- route detail API p95 ≤ 1.5 s on cache hit;
- fresh route calculation p95 ≤ 8 s;
- 99% of verified public route reads return without 5xx;
- 0 leaked secrets in log/fixture scan;
- recommendation deck generation success ≥ 99% daily;
- execution write retry does not create duplicate completion.

Каждый SLO имеет dashboard, alert threshold, owner и runbook link.

### 13.4 Degradation

1. cache hit;
2. provider retry once;
3. previously verified snapshot if still within policy;
4. explicit unavailable state;
5. synthetic only local/test/draft, never silent public fallback.

## 14. Workstreams and delivery order

### B0 — Contract and decisions

**Owner:** backend/platform  
**Repos:** backend + platform  
**IDs:** GIS-01, GIS-02, ROUTE-QUALITY-01

Tasks:

- adopt ADR-010/011;
- add typed settings for provider/key/timeouts;
- freeze normalized routing and quality DTOs;
- define OpenAPI examples and Problem Details;
- record vendor key type/expiry without key value.

DoD:

- ADR status and key separation approved;
- schemas reviewed by backend/mobile;
- no provider JSON in application layer;
- compatibility fixtures committed without secrets.

### B1 — 2ГИС HTTP adapter

**Owner:** backend  
**Repo:** tourism-backend  
**IDs:** GIS-02, GIS-03

Tasks:

- `TwoGisRoutingProvider`;
- mode/filter mapping;
- timeout/retry/circuit breaker;
- response parser and redaction;
- cache key and freshness;
- feature flag default off outside test.

Tests:

- success detailed response;
- alternatives;
- walking/driving/mixed mapping;
- 4xx/5xx/429/timeout;
- malformed geometry;
- key absent from logs/errors;
- demo 50 km boundary.

### B2 — Quality gate and snapshot data

**Owner:** backend/data/editorial  
**Repos:** backend + platform  
**IDs:** GIS-06, ROUTE-QUALITY-02

Tasks:

- migration `route_routing_snapshots`;
- normalize terrain/accessibility/availability;
- geometry topology checks;
- road/trail/water/exclusion checks;
- elevation/difficulty calculation;
- quality status and warning taxonomy;
- editorial review queue for `needs_review`.

DoD:

- no straight-line public route;
- fixture routes cover Yalta/Ai-Petri/coast/water edge cases;
- quality status visible in API and admin;
- snapshot immutability tested.

### B3 — Route API/mobile contract

**Owner:** backend + mobile  
**IDs:** API-ROUTE-01

Tasks:

- extend route detail with optional `routing` object;
- add freshness/warning labels;
- preserve old clients and mock data;
- generate/snapshot OpenAPI;
- add API client fixtures.

### M1 — Map surface and route detail

**Owner:** mobile  
**Repo:** tourism-mobile  
**IDs:** MO-GIS-01

Tasks:

- map abstraction independent of provider;
- render server geometry and stops;
- loading/error/empty/stale states;
- attribution and accessibility;
- route facts breakdown;
- test with API and local fixtures.

Decision gate: use a map rendering library or 2ГИС SDK only after key/license
decision. A backend HTTP key is never embedded for convenience.

### M2 — Active Route / execution

**Owner:** mobile + backend  
**IDs:** MO-FNC-01, MO-FNC-02

Tasks:

- CTA starts execution;
- active screen and progress;
- stop completion, cancel, resume;
- offline outbox and idempotent retry;
- history from API;
- honest manual confirmation copy;
- map uses immutable routing snapshot.

**Mobile slice status (2026-08-29):** CTA, start/resume, active progress,
stop completion, complete/cancel, conflict handling, history via
`GET /route-executions` and L2 secure outbox with idempotent replay against
`client_event_id`/`occurred_at` are implemented. GPS/turn-by-turn and
provider-native map remain open tasks. Backend ledger is migration `0043`
(not yet deployed).

### R1 — Recommendation backend

**Owner:** backend/data  
**IDs:** BE-FNC-04, RECO-01..08  
**Status (2026-08-29):** v1 implemented — migration `0042`, ranker, today/skip
API, lazy generation and dry-run host script. Metrics dashboards and host
cron installation remain. Mobile R2 is wired (`4fddf6d`/`cc5a6e2`).

Tasks:

- [x] feedback/deck tables and indexes;
- [x] ranker v1 with explicit preferences;
- [x] bounded decay/caps/diversity;
- [x] lazy + cron generation script (cron not installed on the host);
- [x] recommendation endpoints;
- [x] explainability code;
- [x] ranker fixtures;
- [ ] metrics dashboards.

### R2 — Recommendation mobile

**Owner:** mobile  
**IDs:** MO-RECO-01..06  
**Status (2026-08-29):** deck fetch, skip feedback and card explanation are
wired; reset/opt-out and a dedicated “why this route” screen remain.

Tasks:

- [x] fetch server deck;
- [x] send skip/feedback idempotently;
- [ ] cache by local date but trust server;
- [ ] empty/offline/retry states;
- [x] card explanation from `explanation_code`;
- [ ] “why this route” screen, reset and opt-out controls;
- [ ] preserve current deck after preference update.

### B4 — Rewards and production hardening

**Owner:** identity/platform  
**IDs:** BE-FNC-02, OPS-01

Tasks:

- reward only after completion policy;
- anti-abuse/idempotent event;
- dashboard/SLO/alerts;
- secret rotation and quota budget;
- staging smoke, rollback and restore exercise.

## 15. Parallelism and dependencies

```text
B0 ──┬──> B1 ──> B2 ──> B3 ──> M1 ──> M2
     │                         └──────> B4
     └──> R1 ──> R2
R7 catalog/data ───────────────┘
```

Allowed parallel work:

- B1 adapter and R1 recommendation schema can proceed after B0;
- M1 can build against fixtures while B1 runs;
- M2 API wiring can start against existing execution API, but production CTA
  waits for routing quality contract;
- editorial/data quality can proceed in parallel with adapter.

Blocking dependencies:

- public rollout blocks on B2 quality gate and vendor terms;
- rewards block on verified completion semantics;
- SDK map block on separate key/subscription decision;
- broad recommendations block on published catalog quality and evaluation
  fixtures.

## 16. Testing strategy

### Unit

- mode/filter mapping;
- score normalization/decay/caps;
- diversity constraints;
- geometry parser/topology;
- elevation/difficulty formulas;
- availability windows/timezones;
- state transitions/idempotency;
- copy/explanation mapping.

### Property-based

- no duplicate deck items;
- caps never exceeded when enough candidates exist;
- score remains bounded 0..1;
- one view cannot create hard category filter;
- completion cannot regress to active;
- retry does not duplicate feedback/reward;
- invalid coordinates never reach provider.

### Integration

- Postgres/PostGIS migration and indexes;
- Redis lock/cache;
- route snapshot immutability;
- owner/BOLA checks;
- provider failure/degradation;
- cron overlap and partial failure;
- preference update → next deck behavior.

### Contract

- 2ГИС responses recorded as sanitized fixtures;
- OpenAPI request/response compatibility;
- Problem Details shape;
- mobile parser with unknown optional fields;
- no real key in CI; optional manual smoke uses protected secret.

### Mobile/device

- iOS and Android real/simulator map smoke;
- 393×852 baseline plus small/large screens;
- dynamic type, screen reader labels, contrast;
- reduced motion;
- background/foreground resume;
- network offline/slow/429/503;
- app restart with active execution.

### Security

- secret grep and image-layer scan;
- API key redaction;
- BOLA on route/execution/recommendation endpoints;
- rate limits and replay/idempotency;
- exact location consent/retention tests if GPS arrives;
- malformed provider payload and SSRF boundary tests;
- admin/editorial override audit.

### Manual field smoke

Before public rollout, a reviewer physically/visually checks a small route set:

1. urban walking route;
2. coastal route;
3. mountain route with elevation;
4. route near water/bridge;
5. car route with dirt/closed-road alternative;
6. unavailable/seasonal stop.

Manual smoke records date, coordinates/route IDs, provider snapshot, warnings,
observed discrepancy and decision. It is evidence, not a promise of universal
field safety.

## 17. Release gates

### Gate A — code/documentation

- validate scripts green;
- migration upgrade tested;
- OpenAPI diff reviewed;
- docs/progress updated;
- no untracked secrets;
- feature flags default safe.

### Gate B — route correctness

- all public routes in selected rollout cohort have quality status;
- no public synthetic geometry without explicit legacy label;
- transport/filter/water/terrain fixtures green;
- freshness and warning fields render in mobile.

### Gate C — user journey

- discover → detail → start → stop → resume → complete/history works;
- failed provider gives actionable state;
- duplicate taps/retries are safe;
- manual completion copy is honest;
- accessibility smoke passes.

### Gate D — recommendations

- preferences affect fixtures;
- views bounded and decayed;
- diversity/exploration caps pass;
- skip cooldown and reset work;
- cold start/offline/empty states work;
- metrics and rollback tested.

### Gate E — operations/security

- key rotation/expiry owner assigned;
- quota and latency alerts tested;
- logs redacted;
- rollback to stub/previous snapshot works;
- backup/restore and incident contact documented;
- legal attribution/terms approved.

## 18. Rollout and rollback

### Feature flags

```text
routing_2gis_enabled
routing_quality_gate_enforced
route_map_enabled
route_execution_mobile_enabled
recommendations_backend_enabled
recommendations_mobile_enabled
rewards_execution_enabled
```

Enable in order: internal test user → test contour → small authenticated cohort
→ selected public routes → wider rollout.

### Rollback levels

1. disable mobile feature flag;
2. switch provider to last verified snapshot/stub for local only;
3. stop new recommendation generation, keep last valid deck;
4. disable rewards without deleting execution history;
5. roll back immutable backend image;
6. database recovery only through separately reviewed plan.

### Vendor expiry

At least seven days before demo key expiry:

- alert owner;
- verify subscription/production key;
- rotate secret;
- run smoke and quota check;
- leave old key available only for rollback window, then revoke.

## 19. Risk register

| Risk | Impact | Mitigation | Owner / trigger |
| --- | --- | --- | --- |
| Demo key expires/has low quota | route outage | expiry alert, cache, fallback snapshot | platform / quota 80% |
| SDK key confused with HTTP key | build/runtime failure or leak | ADR-010 separation, separate secrets | mobile/backend / SDK decision |
| Provider graph lacks hiking trail | unsafe/poor route | OSM/editorial gate, needs_review | data/editorial / missing terrain |
| Filters silently violated | wrong transport path | inspect response, hard reject | backend / filter mismatch |
| Straight line crosses water/cliff | safety/trust incident | geometry/topology gate, no public synthetic | backend / any public synthetic |
| Weather/closure stale | unavailable destination | TTL/freshness/warning | data / expired source |
| Preferences overfit | filter bubble/churn | explicit prior, decay, caps, exploration | product/data / diversity guardrail |
| Recommendation cron fails | stale/empty deck | lazy generation, previous deck, alert | platform / daily failure |
| Manual completion abuse | inflated rewards | delayed reward, idempotency, later proof | identity/product / anomaly |
| GPS privacy overreach | regulatory/trust harm | no GPS in v0, opt-in review | product/legal / feature proposal |
| Mobile map SDK license mismatch | legal/cost risk | separate decision and key | product/legal / SDK request |
| Catalog too small | repetitive deck | editorial/data R7, honest empty state | content / coverage threshold |

## 20. Open decisions with deadlines

| Decision | Default | Deadline |
| --- | --- | --- |
| HTTP provider first | 2ГИС Routing API | B0 |
| Mobile map technology | server geometry + provider-neutral abstraction; SDK after license | before M1 release |
| Demo key rollout | test contour only, 50 km constraint | before B1 smoke |
| Hard vs soft trail filters | safety-critical filters hard; comfort filters soft | before B2 |
| Difficulty formula | versioned deterministic score + unknown state | before B2 |
| Completion proof v0 | manual confirmation, no GPS | before M2 |
| Deck size/cooldown | config 15–20 / 14 days starting values | before R1, revisit after data |
| Strict preference mode | soft by default | before adding more profile fields |
| Weather/opening hours | warning/rerank, not sole SoT | P3 |
| OSRM fallback | defer until catalog/traffic economics justify | post-R-next |

Unresolved decisions must not be hidden inside implementation code.

## 21. Traceability matrix

| User need | Product contract | Backend | Mobile | Tests/docs |
| --- | --- | --- | --- | --- |
| Реальная карта | verified routing snapshot | GIS-02/B2 | M1 | ADR-010, contract/device |
| Не попасть через реку/обрыв | quality gate | ROUTE-QUALITY-02 | warning state | topology fixtures/manual smoke |
| Понятное время | movement/visit/total breakdown | route snapshot | route facts | schema/unit |
| Подходящая сложность | elevation/access taxonomy | difficulty service | badges/warnings | formula/property |
| Продолжить маршрут | execution state machine | route-execution API | Active Route | integration/e2e |
| История | immutable execution snapshot | list endpoint | history | ownership tests |
| Персональная выдача | explicit + bounded behavior | ranker/deck | recommendations deck | offline/property |
| Не зациклиться на горах | caps/exploration | diversity reranker | explanation/reset | mountain-heavy fixture |
| Контроль пользователя | preferences/reset/opt-out | profile + feedback | settings/actions | privacy/widget |
| Не раскрыть ключ | secret boundary | env/adapter | no vendor HTTP key | grep/layer/security |

## 22. Definition of Done для общей цели

Цель считается реализованной только когда одновременно выполнены все пункты:

- [ ] 2ГИС HTTP key type/expiry/terms recorded, secret protected;
- [ ] adapter works with mock and test smoke;
- [ ] route response is normalized and versioned;
- [x] provider result is normalized into GeoJSON/routing metadata without key;
- [x] quality gate v1 rejects missing geometry, invalid legs, pedestrian
  highway contradiction and extreme slope for generated routes;
- [x] movement/visit/total time and altitude metadata are distinct;
- [x] route detail shows source/freshness/quality/warnings;
- [x] provider + stop-data + region road-event gate v1 protects generated
  drafts (full independent terrain/water/access gate remains);
- [x] append-only routing snapshot with DB mutation guard and bounded cleanup
  protects each execution; host retention cron installed 2026-08-29;
- [ ] active execution starts, resumes, updates stops and appears in history;
- [ ] retries and duplicate taps are idempotent;
- [ ] recommendation deck reads preferences without mutating them;
- [ ] views are weak/decayed/capped; diversity and exploration pass fixtures;
- [ ] skip/reset/opt-out controls work;
- [ ] logs, metrics, alerts and rollback are tested;
- [ ] backend/mobile/security/contract/manual gates are green;
- [ ] progress and specialized docs point to the same status;
- [ ] production rollout is feature-flagged and reversible.

## 23. Ссылки на специализированные документы

- [Implementation plan](implementation-plan.md)
- [Progress](progress.md)
- [Readiness review 2026-08-28](implementation-readiness-review-2026-08-28.md)
- [ADR-010: 2ГИС](decisions/ADR-010-2gis-routing-and-map-provider.md)
- [ADR-011: recommendations](decisions/ADR-011-personalized-route-recommendations.md)
- [Route intelligence roadmap](route-intelligence-roadmap.md)
- [Route swipe recommendations](route-swipe-recommendations.md)
- [Mobile functional gaps](reviews/2026-08-27-mobile-functional-gaps-backend-first.md)
- [Security baseline](security/security-baseline.md)
- [Production deploy runbook](production-backend-deploy-runbook.md)

Последнее правило: сначала честность маршрута и пользовательский контроль,
потом автоматизация и «умность». Любая новая фича должна показать, какой
конкретный пользовательский риск или сценарий она улучшает.
