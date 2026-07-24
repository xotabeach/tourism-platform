# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 5 — Flutter foundation (UI по дизайну КрымТрип)
**Последнее обновление:** 2026-07-24

## Сводка фаз

| Phase | Название | Статус |
| --- | --- | --- |
| 0 | Repository audit and conventions | done |
| 1 | Local infrastructure | done |
| 2 | Backend foundation | done |
| 3 | Geography and places | done |
| 4 | Editorial routes | done |
| 5 | Flutter application foundation | in_progress |
| 6 | Authentication | pending |
| 7 | Favorites and profile | pending |
| 8A | Deterministic Route Builder | pending |
| 8B | AI-assisted Route Planning (experimental) | pending |
| 9 | Route execution | pending |
| 10 | Stabilization and staging | pending |
| 11 | User-created routes | pending |
| 12 | Travel+ foundations | pending |
| 13 | Trip Planner | pending |

Статусы: `pending` · `next` · `in_progress` · `done` · `blocked`.

## Что сделано

### Phase 0–2

См. историю выше / git log: docs, Compose, Redis ready, `/api/v1`, error
envelope, JSON logs.

### Phase 3 — Geography and places (2026-07-23)

- Миграция `0002_geography_and_places`: countries/regions/localities,
  categories/places/M2M/entrances/schedules/images; FK + GIST/btree/partial
  unique indexes.
- Документ схемы: [data-model-geography-places.md](data-model-geography-places.md).
- Seed `data/crimea_seed.json` + `scripts/seed_crimea.py` (idempotent, bulk
  `--file` / `--places-only`) — 20 мест Крыма.
- Read API: geography + categories + places list/detail.
- Integration tests против PostGIS/Redis; CI services postgis+redis.
- Mobile: Places catalog/detail, repository interface, mock + API
  implementations (`useMockData` в AppConfig). Freezed отложен на Phase 5.
- Compose `.env.example`: PostGIS `16-3.4` (multi-arch), ports `5433`/`6380`.

### Phase 4 — Editorial routes (2026-07-23)

- Миграция `0003_editorial_routes`: `routes`, `route_stops`, checks/indexes,
  LINESTRING geometry.
- Документ: [data-model-routes.md](data-model-routes.md).
- Seed: 3 editorial routes в `crimea_seed.json` + upsert в `seed_crimea.py`.
- Read API: `GET /api/v1/routes`, `GET /api/v1/routes/{id}` (только public
  editorial/active); фильтры region/transport/difficulty/q.
- Mobile: routes feature (domain/data/application/presentation), catalog +
  detail, вкладка «Маршруты» в shell.

## Что дальше

### Phase 5 — Flutter foundation (продолжение)

Сделано по comparison screenshots Figma:
- `core/design`: semantic colors, typography, spacing, radii, shadows, motion
- Reusable glass surfaces/pills/circles/icon buttons; full Rubik variable font
- Welcome → mock auth (имя/телефон → OTP + согласия) → Home
- Welcome/Home: исправлены crop, scrim, typography, search, hero, travelers
- Route card: Figma hierarchy (author/tags/rating/locality/distance/difficulty)
- Routes: responsive stacked swipe deck, vertical onboarding, green/burgundy
  drag states, restrained rotation/translation, fixed compact indicators,
  spring-back and committed-swipe haptics
- Swipe onboarding is a standalone first deck card with route cards behind it;
  search/filter/nav stay outside its blur. Shared outlined search/filter
  geometry is `58 px`.
- Segmented floating nav: leading/trailing glass + interrupt-safe liquid
  droplet, semantics, 48 px targets, reduced motion
- Figma-exported SVG icon set integrated through central `AppIconography`;
  transparent 128 px white/ink/muted runtime assets, no new dependency
- 10 reviewed goldens at `393×852`; responsive checks at `412×915` and
  `360×740` with text scale `1.3`
- Auth — UI only; реальный OTP/токены — Phase 6
- **Mock-first DX:** dev `useMockData: true` по умолчанию (8 places /
  3 routes + local assets). Docker/backend не нужны для UI.
  API: `flutter run --dart-define=USE_MOCK_DATA=false`.

Остаётся: сверка approximate values и original SVG через Figma Dev Mode,
device screenshot diff, performance profile на mid-range Android; Freezed
optional. Pixel-perfect статус не заявлен без этих проверок.
См. [flutter-app-architecture.md](flutter-app-architecture.md).

### Документировано (не реализовано): AI route planning

Архитектура и ADR-006: provider-neutral AI, Gemini experimental → Gemma + RAG,
editorial-first, form/chat → `NormalizedRouteRequest`, MCP отложен.
См. [ai-route-planning-architecture.md](ai-route-planning-architecture.md).
Реализация — Phase 8B+, не часть Phase 3/4.

## Блокеры и заметки

- Auth strategy: **ADR-007** (JWT access + opaque refresh for mobile; cookies
  later for web/admin). Implementation still Phase 6.
- Routing provider — open decision (ADR-004).
- Не коммитить `.tmp-ref-frames/` и локальные `.env`.
- AI architecture documented only; no Gemini/Gemma/MCP code yet.
- DX: style guides + Cursor workspace settings — see
  [development-environment.md](development-environment.md).
- Security: docs + Cursor skill/rule documented under
  [security/security-baseline.md](security/security-baseline.md). **Not**
  claimed complete; auth/Redis ACL/prod hardening still open.

## Документировано (не реализовано): Security Baseline

Threat model, data classification, API/mobile/storage security docs, ADR-007,
incident response, CI recommendations. Foundation code: input limits, prod
placeholder-secret guard, security pytest, pip-audit job. Full auth — Phase 6.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`.
2. При завершении: итог в «Что сделано», таблицу обновить.
3. Блокеры писать сразу.
4. Детальный backlog — в implementation-plan.
