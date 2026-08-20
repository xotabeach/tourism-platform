# RoutingProvider stub + self-host OSRM (Крым)

Статус: **контракт и stub as-built** (2026-08-20); OSRM extract — план,
ещё не поднят.

Связанные документы:

- [ADR-004](decisions/ADR-004-routing-provider-abstraction.md)
- [ai-route-system-end-to-end.md](ai-route-system-end-to-end.md) §4 шаг D
- [ai-route-planning-architecture.md](ai-route-planning-architecture.md) §16
- [ai-route-match-three-paths.md](ai-route-match-three-paths.md)

## 1. Зачем

LLM / place picker выбирают **точки**, но не дороги. Без дорожного движка
возможен «маршрут через гору/реку» как прямая линия между центрами.

Инвариант: после выбора ordered place IDs всегда вызывается
`RoutingProvider`. Неreachable / слишком длинная нога → repair или
`routing_unreachable` / `route_too_long`, а не «нарисуй polyline в промпте».

## 2. Application port (as-built)

```text
tourism_backend/modules/route_builder/application/routing.py
tourism_backend/modules/route_builder/infrastructure/routing_stub.py
```

Вход:

- `waypoints`: упорядоченные `(lng, lat)` (+ optional `place_id` label);
- `transport_mode`: `walk | car | public | mixed`;
- `constraints`: max_leg_meters, max_total_meters (optional).

Выход:

- `legs[]`: distance_m, duration_s, geometry (LineString WKT или null у stub),
  warnings;
- `total_distance_m`, `total_duration_s`;
- `provider`: `stub` | `osrm`;
- `synthetic`: bool — stub всегда `true` (не navigation-grade).

Ошибки (typed):

| code | смысл |
| --- | --- |
| `routing_unreachable` | нога недостижима при текущем mode/constraints |
| `route_too_long` | суммарная длина/время выше лимита |
| `routing_provider_error` | timeout / 5xx у реального движка |

## 3. Stub (сейчас)

- Haversine × road factor (~1.35) как грубая оценка «по дороге»;
- скорости: walk 4.5 км/ч, car 45 км/ч, public 25 км/ч;
- отказ, если нога > `max_leg_meters` (default walk 25 км, car 120 км);
- geometry = прямая LineString (synthetic), с warning
  `synthetic_straight_line`.

Stub нужен для pipeline/tests без сети. **В production UI** показывать
оценку только с пометкой «приблизительно», пока `synthetic=true`.

## 4. План self-host OSRM по Крыму

### 4.1 Выбрать extract

1. Источник: Geofabrik / BBBike / собственный `osmium extract` по bbox
   Крыма (~44.3–46.3 N, 32.4–36.7 E) — тот же pre-filter, что у place import.
2. Не коммитить `.osm.pbf` в Git; хранить в object storage / локальном volume.
3. Attribution: ODbL; freshness date в metadata ответа RoutingProvider.

### 4.2 Сборка графа

```bash
# примерный поток (на build-хосте с достаточным RAM)
osrm-extract crimea-latest.osm.pbf -p profiles/car.lua
osrm-partition crimea-latest.osrm
osrm-customize crimea-latest.osrm
# отдельно profiles: foot.lua / bicycle.lua по мере нужды
```

Образы: официальный `ghcr.io/project-osrm/osrm-backend` или self-build.

### 4.3 Compose (tourism-platform, optional profile)

```yaml
# черновик — добавить позже как profile "routing"
services:
  osrm-car:
    image: ghcr.io/project-osrm/osrm-backend:latest
    command: osrm-routed --algorithm mld /data/crimea-latest.osrm
    volumes: ["./data/osrm:/data:ro"]
    ports: ["5000:5000"]
    # только private network; не expose в интернет без auth
```

Backend env:

```text
ROUTING_PROVIDER=stub|osrm
OSRM_BASE_URL=http://osrm-car:5000
ROUTING_TIMEOUT_SECONDS=10
```

### 4.4 Adapter `OsrmRoutingProvider`

1. `GET /route/v1/{profile}/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson`
2. Map legs → port DTO; `synthetic=false`.
3. Timeout + typed 5xx → `routing_provider_error`; fallback на stub **только**
   в local/test, не в production generate без явного flag.
4. Учитывать `road_events` как soft warnings на первом срезе; hard exclude
   segments — после того как появится map-matching / custom weights.

### 4.5 Acceptance

1. Generate pipeline всегда вызывает RoutingProvider.
2. Stub green в CI без сети.
3. OSRM smoke: 2 точки Ялта↔Алупка → polyline не пересекает море «напрямую»
   там, где есть дорога (визуальный/geometry check).
4. Unreachable (остров без моста при foot) → typed failure, не silent shortcut.
5. Production generate с `ROUTING_PROVIDER=osrm` не пишет stub geometry как SoT.

## 5. Порядок внедрения

1. ~~Port + stub + unit tests~~ (этот срез).
2. ~~Generate вызывает routing и пишет distance/duration + warnings~~.
3. Скачать Crimea extract + build `.osrm` offline.
4. Compose profile `routing` + `OsrmRoutingProvider`.
5. Soft warnings из `road_events`.
6. Multi-profile (foot/car) и repair loop при unreachable.

## 6. Не делать

- Не просить LLM «нарисовать дорогу».
- Не класть дорожный граф в Qdrant/RAG.
- Не считать stub navigation-grade.
- Не резать весь backend на микросервисы ради OSRM — достаточно sidecar
  контейнера (см. ADR-001).
