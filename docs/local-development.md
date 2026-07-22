# Локальная разработка

## Область применения

Локальный контур предназначен для разработки и интеграционных проверок на
macOS. Он не является production environment и не задаёт production topology,
security hardening, backup или scaling policy.

## Предварительные требования

- macOS или Linux;
- Git и Make;
- Docker Desktop с Compose v2;
- GitLab CLI для подключения private submodules;
- PowerShell 7 только для запуска `.ps1` scripts.

## Base services

`compose.yaml` поднимает только локальные infrastructure dependencies:

- `postgres` — PostgreSQL database `tourism` с доступным PostGIS;
- `redis` — cache и краткоживущее состояние;
- `minio` — S3-compatible local storage;
- `minio-init` — one-shot создание bucket `tourism-media`;
- `mailpit` — SMTP catcher и web UI.

Сервисы используют healthchecks, named volumes и отдельную bridge network.
Backend и Flutter в этот Compose не входят: они находятся в отдельных
repositories `tourism-backend` и `tourism-mobile` и подключаются к local stack
через published ports PostgreSQL и Redis.

Kafka также не входит в текущий Compose. Согласно ADR-005 broker добавляется
только после появления подтверждённого producer/consumer flow и отдельного
activation decision. До этого domain events обрабатываются in-process.

## Environment

Команда `make init` проверяет Docker Compose и копирует `.env.example` в `.env`
только при отсутствии `.env`. Существующий файл не перезаписывается.

Файл `.env.example` содержит image tags, local ports, имя database, имя MinIO
bucket и безопасные только для developer machine credentials. `.env` исключён
из Git. Эти значения нельзя использовать в staging или production.

Foundation не требует credentials внешнего routing provider.

## Make commands

```text
make help
make init
make up
make down
make restart
make ps
make logs
make validate
make clone-repositories
make clean CONFIRM=yes
```

Команды должны быть повторяемыми, завершаться с ненулевым code при ошибке и не
зависеть от production credentials.

`make clean` удаляет named volumes и локальные данные. Без точного
`CONFIRM=yes` команда обязана завершиться с ошибкой до вызова Docker.

## Первый запуск

1. Выполнить `make init`.
2. При необходимости изменить только local ports в `.env`.
3. Выполнить `make up`.
4. Проверить состояние через `make ps`.
5. Открыть MinIO Console на `http://localhost:9001`.
6. Открыть Mailpit на `http://localhost:8025`.
7. Выполнить `make validate` перед pull request.

## Submodules implementation repositories

`tourism-backend` и `tourism-mobile` уже доступны как private Git submodules
superproject. Для `tourism-infrastructure` и `tourism-documentation` команда
`make clone-repositories` проверит `git`, `gh`, authorization, superproject и
доступность всех remotes, затем добавит их как Git submodules рядом с
`tourism-platform`. Скрипт не перезаписывает существующие каталоги.

### Backend и mobile после `make init`

```bash
# infrastructure
make up

# backend (из tourism-backend/)
cp .env.example .env
uv sync --all-extras --dev
uv run alembic upgrade head
uv run tourism-backend

# mobile (из tourism-mobile/)
flutter pub get
flutter run
```

## Ограничения

- Demo data не должны содержать реальные персональные данные.
- Local object storage и database считаются расходными.
- Compose credentials допустимы только для local environment.
- `minio-init` является one-shot container и после успешного создания bucket
  завершается с code `0`.
- Local Kafka profile не создаётся заранее. При активации он должен повторять
  production-relevant KRaft и security assumptions в разумных для developer
  machine пределах.
- Production deployment, certificates, secret management и backups описываются
  отдельно в infrastructure repository.
