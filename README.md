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

Планы, ранбуки, ревью и заметки по инфраструктуре в репозиторий не входят:
они описывают конкретные серверы и процессы команды и лежат у разработчиков
локально (см. `.gitignore`). Здесь остаётся общее описание продукта, модели
данных и правил работы.

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
- AI: port `AIPlanningProvider` → mock / Gemini / DeepSeek / LM Studio.
- Kafka — только после ADR-005. Helm — позже в этом repo.

Ключевые решения: [docs/decisions](docs/decisions).

Продуктовая логика и правила работы:
[application-business-logic.md](docs/application-business-logic.md),
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
во внутренней документации.

## Структура

```text
.
├── .gitlab-ci.yml      # lean CI
├── .gitlab-ci.full.yml # полный DevSecOps
├── deploy/test/        # Caddy + backend + PostGIS + Redis
├── docs/               # общее: стек, ADR, модели данных, правила работы
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

## Документация

- [Стек](docs/stack.md)
- [Product vision](docs/product-vision.md)
- [System context](docs/system-context.md)
- [Business logic](docs/application-business-logic.md)
- [Domain model](docs/domain-model.md)
- [Модель данных: география и места](docs/data-model-geography-places.md)
- [Модель данных: маршруты](docs/data-model-routes.md)
- [Architecture decisions](docs/decisions)
- [Development conventions](docs/development-conventions.md)
- [Development environment](docs/development-environment.md)
- [Local development](docs/local-development.md)
- [Repository strategy](docs/repository-strategy.md)
- Python: [code style](docs/python-code-style.md), [testing](docs/python-testing-guide.md)
- Flutter: [архитектура](docs/flutter-app-architecture.md),
  [code style](docs/flutter-code-style.md),
  [дизайн-система](docs/flutter-design-system.md),
  [testing](docs/flutter-testing-guide.md)

Внутренние документы — планы, ранбуки деплоя, ревью, разборы инцидентов,
заметки по безопасности и всё, что описывает конкретные серверы, — в
репозиторий не входят и лежат локально.

## Дальнейшие шаги

1. B0/B1 — 2ГИС HTTP contract, adapter и test-contour smoke.
2. B2 — routing snapshots и route quality gate.
3. M1/M2 — карта, активное прохождение, resume и history.
4. R1/R2 — recommendations v1 с preferences, diversity и feedback.
5. Rewards и production hardening после выполнения release gates.
