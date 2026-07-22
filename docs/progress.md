# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 2 — Backend foundation (следующая к выполнению)  
**Последнее обновление:** 2026-07-22

## Сводка фаз

| Phase | Название | Статус |
| --- | --- | --- |
| 0 | Repository audit and conventions | done |
| 1 | Local infrastructure | done |
| 2 | Backend foundation | next |
| 3 | Geography and places | pending |
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
- Добавлены:
  - [application-business-logic.md](application-business-logic.md)
  - [implementation-plan.md](implementation-plan.md)
  - [development-conventions.md](development-conventions.md)
- Domain model: единый `Route` + `RouteExecution` + sketch Trip/Travel+.
- Conventions: branches, commits, MR, API `/api/v1`, env naming.
- GitLab — primary CI; GitHub workflows оставлены как legacy.

### Phase 1 — Local infrastructure (2026-07-22)

- Compose в `tourism-platform` подтверждён (PostGIS, Redis, MinIO, Mailpit).
- Backend: `REDIS_URL`, ready проверяет PostgreSQL + Redis.
- Health: `/health/live`, `/health/ready` (+ aliases `/health`, `/ready`).
- Dockerfile + CI image build без push в registry.
- Mobile: `dart format` в `validate.sh`.
- Workspace CI: проверка `docs/` index.
- Запушено в `travel-platform2` (platform `9b2a4e0`, backend `9a19ae3`,
  mobile `d64cf71`, workspace `9fab546`).

## Что дальше

### Phase 2 — Backend foundation

Цель: pragmatic clean architecture layers, error model, prefix `/api/v1`,
базовые module packages без полной бизнес-логики.

Ожидаемо:

- shared DB base / error handlers / structured logging уже частично есть —
  довести;
- versioned API router skeleton;
- не реализовывать auth/places/routes в этой фазе.

После Phase 2 → Phase 3 (geography and places).

## Блокеры и заметки

- Локальный `docker build` backend на машине разработчика не был проверен
  (Docker daemon был выключен); проверка образа ожидается в GitLab CI job
  `backend-image`.
- Auth (JWT vs session) и конкретный routing provider для staging — open
  decisions, фиксировать ADR при старте соответствующих фаз.
- Не коммитить `.tmp-ref-frames/` в workspace.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`, кратко цель в «Что дальше».
2. При завершении: перенести итог в «Что сделано», дату, ключевые SHA/MR.
3. Таблицу сводки обновить (`done` / `next`).
4. Блокеры писать сразу, не ждать конца фазы.
5. Не дублировать весь backlog — ссылаться на implementation-plan.
