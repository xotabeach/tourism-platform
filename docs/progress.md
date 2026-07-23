# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 4 — Editorial routes (следующая)  
**Последнее обновление:** 2026-07-23

## Сводка фаз

| Phase | Название | Статус |
| --- | --- | --- |
| 0 | Repository audit and conventions | done |
| 1 | Local infrastructure | done |
| 2 | Backend foundation | done |
| 3 | Geography and places | done |
| 4 | Editorial routes | next |
| 5 | Flutter application foundation | pending |
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

## Что дальше

### Phase 4 — Editorial routes

Публичные editorial routes, фильтры, карточка маршрута со stops.

### Документировано (не реализовано): AI route planning

Архитектура и ADR-006: provider-neutral AI, Gemini experimental → Gemma + RAG,
editorial-first, form/chat → `NormalizedRouteRequest`, MCP отложен.
См. [ai-route-planning-architecture.md](ai-route-planning-architecture.md).
Реализация — Phase 8B+, не часть Phase 3/4.

## Блокеры и заметки

- Auth (JWT vs session) и routing provider — open decisions.
- Не коммитить `.tmp-ref-frames/` и локальные `.env`.
- AI architecture documented only; no Gemini/Gemma/MCP code yet.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`.
2. При завершении: итог в «Что сделано», таблицу обновить.
3. Блокеры писать сразу.
4. Детальный backlog — в implementation-plan.
