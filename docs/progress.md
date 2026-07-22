# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 3 — Geography and places (следующая)  
**Последнее обновление:** 2026-07-22

## Сводка фаз

| Phase | Название | Статус |
| --- | --- | --- |
| 0 | Repository audit and conventions | done |
| 1 | Local infrastructure | done |
| 2 | Backend foundation | done |
| 3 | Geography and places | next |
| 4 | Editorial routes | pending |
| 5 | Flutter application foundation | pending |
| 6 | Authentication | pending |
| 7 | Favorites and profile | pending |
| 8 | Route builder | pending |
| 9 | Route execution | pending |
| 10 | Stabilization and staging | pending |
| 11 | User-created routes | pending |
| 12 | Travel+ foundations | pending |
| 13 | Trip Planner | pending |

Статусы: `pending` · `next` · `in_progress` · `done` · `blocked`.

## Что сделано

### Phase 0 — Repository audit and conventions (2026-07-22)

- Зафиксирована модель из 4 repos: `workspace`, `tourism-platform`,
  `tourism-backend`, `tourism-mobile` (без отдельных infra/docs repos).
- Канон документации в `tourism-platform/docs/`; индекс в `workspace/docs/`.
- Добавлены business-logic, implementation-plan, development-conventions.
- Domain model: единый `Route` + `RouteExecution` + sketch Trip/Travel+.
- GitLab — primary CI.

### Phase 1 — Local infrastructure (2026-07-22)

- Compose (PostGIS, Redis, MinIO, Mailpit); Redis в backend ready.
- Health `/health/live` + `/health/ready`; Dockerfile + CI image build.
- Mobile `dart format` в validate; progress log заведён.

### Phase 2 — Backend foundation (2026-07-22)

- SQLAlchemy `Base` + UUID/timestamp mixins + naming convention.
- Stable JSON error envelope (`AppError`, HTTP, validation handlers).
- Structured JSON logging.
- Versioned API root: `GET /api/v1`.
- Module package markers: `route_execution`, `favorites`, `subscriptions`.
- Alembic `target_metadata = Base.metadata`.
- Tests: health + API foundation (8 passed).

### CI fix (2026-07-22)

- Workspace pipeline падал без jobs: unquoted `NOTE:` в `.gitlab-ci.yml`
  ломал YAML. Исправлено folded scalar; pipeline `2697046789` — success.

## Что дальше

### Phase 3 — Geography and places

Цель: Country/Region/Locality, categories, places catalog + detail API;
mobile repository interfaces/mocks и экраны каталога/карточки.

После Phase 3 → Phase 4 (editorial routes) и/или Phase 5 (Flutter shell)
по приоритету команды.

## Блокеры и заметки

- Auth (JWT vs session) и routing provider для staging — open decisions (ADR).
- Не коммитить `.tmp-ref-frames/` в workspace.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`, кратко цель в «Что дальше».
2. При завершении: перенести итог в «Что сделано», дату, ключевые SHA/MR.
3. Таблицу сводки обновить (`done` / `next`).
4. Блокеры писать сразу, не ждать конца фазы.
5. Не дублировать весь backlog — ссылаться на implementation-plan.
