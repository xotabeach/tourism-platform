# ADR-010 — 2ГИС для дорожной маршрутизации и карт

- **Статус:** proposed / test-contour approved, production rollout pending
- **Дата:** 2026-08-28
- **Владельцы:** backend + mobile + platform
- **Связанные решения:** ADR-004 (RoutingProvider), ADR-009 (data-first),
  Phase 9/9.5, R10

## Контекст

Сейчас `RoutingProvider` имеет рабочий deterministic stub, который вычисляет
`haversine × 1.35` и возвращает прямую `LINESTRING`. Это полезно для unit и
local UI, но не является навигацией: прямая может пересекать реку, обрыв,
закрытую территорию или участок, непригодный для выбранного транспорта.

Крымский продукт нуждается в:

- дорожной geometry;
- раздельных режимах walking/driving/bicycle/public transport;
- реальном distance/duration и альтернативных вариантах;
- road/trail filters, exclusions и закрытиях;
- elevation profile для пеших и велосипедных маршрутов;
- понятном отказе, если граф не подтверждает путь.

2ГИС предоставил API-ключ для тестирования. По актуальной документации:

- бесплатный demo key действует один месяц и предназначен для API;
- demo key нельзя использовать с Mobile SDK;
- ключ для Mobile SDK создаётся отдельно в подписке;
- ключ с App ID ограничен SDK и не предназначен для прямых HTTP-запросов;
- Routing API поддерживает `/routing/7.0.0/global`, режимы транспорта,
  detailed geometry, filters, exclusions, alternatives и altitude data;
- demo-ключ ограничивает максимальную длину маршрута 50 км.

Ссылки: [ключи 2ГИС](https://docs.2gis.com/en/platform-manager/subscription/keys),
[Routing API](https://docs.2gis.com/en/api/navigation/routing/overview),
[Flutter Map SDK](https://docs.2gis.com/en/flutter/sdk/examples/map).

## Решение

### 1. Разделить два продукта и два типа ключей

**На первом этапе используем только server-side HTTP Routing API.**

```text
Mobile → КрымТрип API → TwoGisRoutingProvider → 2GIS Routing API
```

Ключ backend хранится в secret manager/env и никогда не возвращается mobile.
Если позднее понадобится нативная 2ГИС-карта, создаются отдельные SDK-ключи
для iOS и Android/Flutter в соответствии с лицензией и App ID. Backend HTTP
key и SDK key не взаимозаменяемы.

### 2. Сохранить provider-neutral application port

`RoutingProvider` остаётся единственным портом application layer. 2ГИС
реализуется в infrastructure adapter и выбирается конфигурацией:

```env
ROUTING_PROVIDER=2gis
TWO_GIS_ROUTING_BASE_URL=https://routing.api.2gis.com
TWO_GIS_HTTP_API_KEY=<secret>
```

Поддерживаемые значения конфигурации должны быть typed и fail-closed:
`stub` (local/tests), `2gis` (test/production after approval), позднее `osrm`
или другой совместимый provider.

### 3. Нормализовать внутренние и внешние режимы

| КрымТрип | 2ГИС | Политика |
| --- | --- | --- |
| `walk` | `walking` | pedestrian graph, stairs/road/access checks, altitude |
| `car` | `driving` | roads, closures, dirt/toll policy, no pedestrian-only paths |
| `public` | `public_transport/2.0` | отдельный контракт, schedule-aware |
| `mixed` | композиция legs | не скрывать пересадки и pedestrian portions |
| `bicycle` (будущее) | `bicycle` | отдельные filters и slope policy |

2ГИС-специфичные имена не протекают в mobile domain model.

## Quality and safety policy

### Hard constraints

Нарушение hard constraint означает `unusable`/`needs_review`, а не тихий
fallback на прямую линию:

- минимум две валидные точки;
- выбранный transport соответствует запросу;
- точки находятся в пределах допустимой дистанции притяжения к графу;
- нет `ROUTE_NOT_FOUND`, `ROUTE_DOES_NOT_EXISTS`, `POINT_EXCLUDED`,
  `ATTRACT_FAIL`;
- нет запрещённого доступа, непереходимой воды или исключённой зоны;
- автомобильный маршрут не содержит пешеходные-only segments;
- обязательный stop reachable по выбранному режиму;
- длина, набор высоты, уклон и длительность укладываются в пользовательские
  hard limits;
- если provider нарушил requested hard filter, результат не считается
  verified.

### Soft constraints

Soft constraints влияют на выбор альтернативы и предупреждения:

- dirt road, stairs, ferry, toll road;
- crowding, shade, surface quality;
- временная погода и сезонность;
- предпочитаемая сложность и темп;
- доступность туалетов, покрытия связи и мест отдыха.

Если 2ГИС возвращает маршрут, несмотря на filter, это явно записывается в
`warnings` и показывается пользователю; нельзя утверждать «избегает всегда».

### Quality status

```text
unverified → checking → verified
                     ↘ verified_with_warnings
                     ↘ needs_review
                     ↘ unusable
```

Только `verified` и, при явном согласии пользователя, `verified_with_warnings`
могут попасть в обычный public catalog. `unusable` и необъяснимый synthetic
результат не публикуются.

## Data contract

Миграции `0039_route_routing_snapshots` и `0040_snapshot_immutable` хранят
отдельный routing snapshot, а не перезаписывают историю в `routes`:

```text
route_routing_snapshots
  id, route_id, revision, fingerprint
  provider, provider_version, transport_mode, geometry
  distance_meters, movement_duration_seconds, visit_duration_minutes
  transfer_duration_seconds, buffer_duration_seconds, total_duration_seconds
  elevation_gain_meters, elevation_loss_meters
  min_altitude_meters, max_altitude_meters, max_road_angle_degrees
  road_types, requested_filters, quality_status, quality_policy_version
  warnings, route_updated_at, captured_at, created_at
```

Сырые ответы 2ГИС не сохраняются без проверки лицензии и необходимости;
достаточно нормализованных полей и fingerprint для диагностики. `RouteExecution`
ссылается на snapshot, чтобы изменение внешнего графа не меняло уже начатое
прохождение задним числом. После вставки snapshot защищён PostgreSQL trigger;
bounded cleanup удаляет только старые, неиспользуемые и не последние revision,
а расписание/алерты остаются операционной задачей.

## Failure and fallback

1. 2ГИС timeout/5xx/rate-limit → retry с bounded backoff, затем typed
   `routing_provider_unavailable`.
2. 2ГИС 4xx/invalid request → не повторять без изменения input, вернуть
   исправимый `routing_request_invalid`.
3. Нет маршрута/quality gate failed → `route_unavailable` с безопасным
   объяснением.
4. Synthetic stub разрешён только local/test или явно помеченному draft;
   production public route не должен незаметно деградировать в прямую линию.
5. При переключении провайдера сохраняем `provider` и `quality_status` в
   ответе, чтобы пользователь видел свежесть и источник geometry.

## Security and privacy

- ключи в secret manager/env, rotation без commit;
- URL и query string с `key` не логируются;
- request/response logs содержат только correlation id, provider, status,
  latency и агрегированные размеры;
- точная геолокация пользователя в v0 не отправляется: route строится по
  сохранённым публичным stops; live GPS — отдельный opt-in проект;
- отдельные server/mobile keys и отдельные quota/budget alerts;
- vendor terms, attribution и допустимость кэширования проходят legal/product
  review до production.

## Consequences

### Плюсы

- реальная дорожная geometry и ETA быстрее дают полезный пользовательский
  результат;
- provider port сохраняет возможность OSRM/self-host и тестового stub;
- качество маршрута становится измеримым и объяснимым;
- ключ не раскрывается клиенту.

### Минусы и ограничения

- demo key временный и ограничен 50 км;
- cloud provider создаёт зависимость от квот, цены и доступности сети;
- 2ГИС не является гарантией hiking safety или актуальности каждой тропы;
- Mobile SDK потребует отдельной подписки и native integration work;
- дополнительный quality gate увеличивает latency и число маршрутов
  `needs_review`.

## Acceptance for changing status to accepted

- test key успешно вызывает Routing API с двумя и несколькими точками;
- mock contract tests покрывают success, alternatives, statuses, filters,
  altitude и malformed response;
- integration smoke на двух реальных маршрутах Крыма не пересекает воду/явно
  недоступные зоны;
- provider, freshness, distance, movement time и warnings видны в API;
- ключ не находится в git, logs, OpenAPI examples или mobile bundle;
- quality gate и rollback feature flag проверены;
- получены письменные условия 2ГИС для production и, отдельно, Mobile SDK.

До выполнения последнего пункта ADR остаётся `test-contour approved`, а не
production commitment.
