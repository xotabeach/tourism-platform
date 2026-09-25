# Crimea Travel Platform

КРЫМТРИП — мобильная туристическая платформа. Первый контентный контур — Республика Крым; доменная модель
для нескольких стран и регионов.

Проект не является официальным государственным приложением и не заявляет об
официальном партнёрстве с государственными организациями.

## Текущий статус

Здесь находятся общая документация, ADR, локальный Compose и конфигурация
развёртывания (`deploy/test`). Актуальный срез реализованных функций и
ограничений: [docs/current-status.md](docs/current-status.md). Детали стека:
[docs/stack.md](docs/stack.md).

Планы, ранбуки, ревью и заметки по инфраструктуре в репозиторий не входят:
они описывают конкретные серверы и процессы команды и лежат у разработчиков
локально (см. `.gitignore`). Здесь остаётся общее описание продукта, модели
данных и правил работы.

## Архитектурное направление

- Flutter-клиент, feature-first, Riverpod / GoRouter / Dio.
- Python 3.13, FastAPI, modular monolith.
- PostgreSQL/PostGIS, Redis; MinIO + Mailpit локально.
- Test host: Caddy + backend + PostGIS + Redis.
- Границы модулей включают `identity`, `geography`, `places`, `routes`, `content`,
  `support`, `admin`, `route_builder` и `route_execution`.
- `RoutingProvider` поддерживает локальную заглушку, 2ГИС и Valhalla; выбор
  провайдера зависит от конфигурации окружения.
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
| `tourism-landing` | Публичный сайт и ссылка на APK |

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
├── tourism-backend/
└── tourism-landing/
```

## Legacy reference

Исходная продуктовая идея изучена по
[дипломному Android-проекту](https://github.com/xotabeach/Diploma-project-Mobile-application-for-the-Department-of-Tourism-of-Tatarstan).
Он используется только как источник сценариев и терминологии.

Старые Java-классы, Android UI, ресурсы, изображения, тексты, API-ключи,
структура и технические решения не переносятся. Новая система создаётся с нуля.

## Документация

- [Стек](docs/stack.md)
- [Текущий статус](docs/current-status.md)
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
