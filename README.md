# Crimea Travel Platform

Crimea Travel Platform — рабочее название мобильной туристической платформы
(CrimeaTrip). Первый контентный контур — Республика Крым; доменная модель
для нескольких стран и регионов.

Проект не является официальным государственным приложением и не заявляет об
официальном партнёрстве с государственными организациями.

## Текущий статус

Канонические docs, ADR, local Compose и test-deploy (`deploy/test`) живут
здесь. Backend и mobile — отдельные submodules, не skeleton.

As-built: каталог, auth, избранное, публикация маршрутов + SQLAdmin,
профиль (тп/звания), отзывы, inbox/FCM, Route Builder и экспериментальный
Phase 8B AI-чат с planning sessions. Выбранный home lab — Windows LM Studio +
Unsloth Gemma 4 26B A4B it UD-IQ4_XS; transport/probe подключены. В локальном
и серверном PostGIS импортировано по 1000 OSM drafts для quality gate.

- Стек: [docs/stack.md](docs/stack.md)
- Прогресс: [docs/progress.md](docs/progress.md)
- Единый план текущего инкремента: [implementation blueprint](docs/implementation-blueprint-2026-08.md)

## Архитектурное направление

- Flutter-клиент, feature-first, Riverpod / GoRouter / Dio.
- Python 3.13, FastAPI, modular monolith.
- PostgreSQL/PostGIS, Redis; MinIO + Mailpit локально.
- Test host: Caddy + backend + PostGIS + Redis.
- Границы модулей: `identity`, `geography`, `places`, `routes`, `favorites`,
  `support`, `notifications`, `admin`, `media`, `route_execution`; backend
  route-execution v0 уже доступен, mobile journey ещё в работе.
- `RoutingProvider` — абстракция (ADR-004/010); текущая реализация для local —
  deterministic stub с коэффициентом расстояния, первым внешним test-contour
  provider выбран 2ГИС HTTP Routing API. Public synthetic geometry не считается
  навигацией; OSRM остаётся будущим self-hosted вариантом.
- AI: port `AIPlanningProvider` → mock / Gemini / **LM Studio Gemma 4**
  ([ai-self-hosted-home-lab.md](docs/ai-self-hosted-home-lab.md)).
- Kafka — только после ADR-005. Helm — позже в этом repo.

Ключевые решения: [docs/decisions](docs/decisions).

Продуктовая логика и план:
[application-business-logic.md](docs/application-business-logic.md),
[implementation-plan.md](docs/implementation-plan.md),
[development-conventions.md](docs/development-conventions.md).

## Репозитории

| Repository | Назначение |
| --- | --- |
| `workspace` | Git superproject, Makefile, submodule pointers |
| `tourism-platform` | Документация, local Compose, `deploy/test` |
| `tourism-mobile` | Flutter Android и iOS |
| `tourism-backend` | Модульный Python backend |

Дополнительные repositories не создаются. Superproject фиксирует совместимые
commits submodules.

## Требования

- macOS или Linux;
- Git;
- GitLab CLI (`glab`) для подключения submodules;
- Docker Desktop или Docker Engine с Compose v2;
- GNU Make;
- PowerShell 7 — только для запуска PowerShell-вариантов скриптов.

## Быстрый локальный запуск

```bash
make init
make up
make ps
```

Локально поднимаются PostgreSQL/PostGIS, Redis, MinIO и Mailpit. Backend и
Flutter в этот Compose не входят. Kafka не запускается до ADR-005.

После запуска (порты из `.env.example`):

- PostgreSQL: `localhost:5433`;
- Redis: `localhost:6380`;
- MinIO API: `http://localhost:9000`;
- MinIO Console: `http://localhost:9001`;
- Mailpit: `http://localhost:8025`.

Image Postgres: `postgis/postgis:16-3.4` (linux/arm64 + amd64).

Все порты настраиваются через `.env`. Стек целиком: [docs/stack.md](docs/stack.md).

## Команды Makefile

| Команда | Назначение |
| --- | --- |
| `make help` | Показать справку |
| `make init` | Проверить зависимости и создать локальный `.env` |
| `make up` | Запустить инфраструктуру |
| `make down` | Остановить инфраструктуру |
| `make restart` | Перезапустить инфраструктуру |
| `make ps` | Показать состояние контейнеров |
| `make logs` | Следить за логами |
| `make clean CONFIRM=yes` | Удалить контейнеры и локальные volumes |
| `make validate` | Локальные проверки docs/compose |
| `make clone-repositories` | Legacy helper; infra/docs repos не создаются |

`make clean` без `CONFIRM=yes` никогда не удаляет volumes.

Перед commit: `./scripts/validate.sh`. GitLab CI по умолчанию lean —
[ci-and-runners.md](docs/ci-and-runners.md).

## Структура

```text
.
├── .gitlab-ci.yml      # lean CI
├── .gitlab-ci.full.yml # полный DevSecOps
├── deploy/test/        # Caddy + backend + PostGIS + Redis
├── docs/               # канон: стек, ADR, фазы, security
├── scripts/
├── compose.yaml        # local DX: PostGIS, Redis, MinIO, Mailpit
├── Makefile
└── README.md
```

Ожидаемая структура workspace:

```text
workspace/
├── docs/
├── tourism-platform/
├── tourism-mobile/
└── tourism-backend/
```

## Legacy reference

Исходная продуктовая идея изучена по
[дипломному Android-проекту](https://github.com/xotabeach/Diploma-project-Mobile-application-for-the-Department-of-Tourism-of-Tatarstan).
Он используется только как источник сценариев и терминологии.

Старые Java-классы, Android UI, ресурсы, изображения, тексты, API-ключи,
структура и технические решения не переносятся. Новая система создаётся с нуля.
Подробности:
[legacy-project-analysis.md](docs/legacy-project-analysis.md).

## Документация

- [Стек](docs/stack.md)
- [Progress](docs/progress.md)
- [Business logic](docs/application-business-logic.md)
- [Implementation plan](docs/implementation-plan.md)
- [Implementation blueprint 2026-08](docs/implementation-blueprint-2026-08.md)
- [Implementation readiness review 2026-08-28](docs/implementation-readiness-review-2026-08-28.md)
- [Development conventions](docs/development-conventions.md)
- [Product vision](docs/product-vision.md)
- [System context](docs/system-context.md)
- [Domain model](docs/domain-model.md)
- [Repository strategy](docs/repository-strategy.md)
- [Local development](docs/local-development.md)
- [Home lab Gemma 4](docs/ai-self-hosted-home-lab.md)
- [Windows LM Studio + Gemma 4 26B](docs/ai-lm-studio-windows-gemma4.md)
- [PostGIS bulk import 1000+](docs/crimea-places-bulk-import-plan.md)
- [AI-чат и генерация маршрута](docs/ai-route-chat-mobile-implementation.md)
- [Architecture decisions](docs/decisions)
- [CI / runners](docs/ci-and-runners.md)
- [Production backend deploy runbook](docs/production-backend-deploy-runbook.md)

## Дальнейшие шаги

1. B0/B1 — 2ГИС HTTP contract, adapter и test-contour smoke.
2. B2 — routing snapshots и route quality gate.
3. M1/M2 — карта, активное прохождение, resume и history.
4. R1/R2 — recommendations v1 с preferences, diversity и feedback.
5. Rewards и production hardening после выполнения release gates.
