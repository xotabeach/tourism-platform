# Локальная разработка

## Область применения

Локальный контур — developer machine (macOS/Linux). Это не production и не
test-сервер. Полная картина контуров (включая Gemma 4 home lab):
[stack.md](stack.md).

## Предварительные требования

- macOS или Linux;
- Git и Make;
- Docker Desktop с Compose v2;
- GitLab CLI для private submodules;
- PowerShell 7 только для `.ps1` scripts.

## Base services

`compose.yaml` поднимает только local infrastructure:

- `postgres` — PostgreSQL `tourism` с PostGIS;
- `redis` — cache и краткоживущее состояние;
- `minio` — S3-compatible storage;
- `minio-init` — one-shot bucket `tourism-media`;
- `mailpit` — SMTP catcher и web UI.

Healthchecks, named volumes, bridge network. Bind портов — `127.0.0.1`.

Backend и Flutter **не** в этом Compose: `tourism-backend` / `tourism-mobile`
на хосте, порты Postgres/Redis.

**Не входят** в local Compose: Caddy, Kafka, Ollama, Qdrant. AI inference —
отдельный GPU home lab, не эта машина по умолчанию
([ai-self-hosted-home-lab.md](ai-self-hosted-home-lab.md)).

Kafka — только после ADR-005. До этого domain events in-process.

Test-сервер (Caddy + backend + PostGIS + Redis):
[environment-and-backend-deployment.md](environment-and-backend-deployment.md),
каталог `deploy/test/`.

## Environment

`make init` проверяет Docker Compose и копирует `.env.example` → `.env`,
если `.env` ещё нет. Существующий файл не перезаписывается.

`.env.example` — image tags, local ports, credentials только для developer
machine. `.env` в Git не коммитится. Эти значения нельзя использовать в
staging/production.

Foundation-эпохи «нет routing credentials» по-прежнему верно: Phase 8A ещё
не подключает внешний `RoutingProvider`.

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

Команды повторяемые, ненулевой code при ошибке, без production credentials.

`make clean` удаляет named volumes. Без `CONFIRM=yes` — ошибка до Docker.

`make clone-repositories` — legacy helper. Репозитории
`tourism-infrastructure` / `tourism-documentation` **не создаются**; infra и
docs живут в этом repo.

## Первый запуск

1. `make init`.
2. При необходимости — только local ports в `.env`.
3. `make up`.
4. `make ps`.
5. MinIO Console: `http://localhost:9001`.
6. Mailpit: `http://localhost:8025`.
7. Backend из `tourism-backend/`; SQLAdmin: `http://localhost:8000/admin`.
8. `make validate` / `./scripts/validate.sh` перед MR.

## Submodules

`tourism-backend` и `tourism-mobile` — private Git submodules superproject.
Канон: [application-business-logic.md](application-business-logic.md),
[implementation-plan.md](implementation-plan.md),
[development-conventions.md](development-conventions.md).

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

GitLab CI lean: стиль и тесты backend/mobile гонять локально
(`./scripts/validate.sh`). См. [ci-and-runners.md](ci-and-runners.md).

## Ограничения

- Demo data без реальных ПДн.
- Local object storage и database расходные.
- Compose credentials только для local.
- `minio-init` — one-shot, после успеха code `0`.
- Local Kafka profile заранее не создаётся.
- Server deploy, TLS, secrets, backups:
  [environment-and-backend-deployment.md](environment-and-backend-deployment.md).
