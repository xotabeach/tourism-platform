# Development conventions

Соглашения для всех репозиториев группы
[`travel-platform2`](https://gitlab.com/travel-platform2). Документация на
русском; technical identifiers — на английском.

Primary CI/CD: **GitLab CI**. GitHub Actions в репозиториях могут оставаться как
legacy/mirror и не являются источником истины.

Базовый CI-паттерн:

- Default **lean** `.gitlab-ci.yml` — notice / publish / manual deploy; не
  style+tests на shared runners. Локально: `./scripts/validate.sh`.
- Полный набор (`code-style`, `run-tests`, scanners) — `.gitlab-ci.full.yml`
  при `CI_PIPELINE_MODE=full`.
- `mirror` — GitHub showcase после успешного job, если токен задан.

См. [ci-and-runners.md](ci-and-runners.md).

## GitHub showcase mirror

Источник истины — GitLab (`travel-platform2`). GitHub (`xotabeach/*`) —
read-only витрина.

После успешного pipeline (lean: notice/publish; full: `code-style` +
`run-tests`) job `github-mirror` может пушить текущий commit:

- `HEAD → github/<branch>` (обычно `gamma`);
- дополнительно `HEAD → github/main`, если ветка `gamma` или `main`.

Нужные **group** CI/CD variables в GitLab (`travel-platform2`):

| Variable | Masked | Назначение |
| --- | --- | --- |
| `GITHUB_MIRROR_TOKEN` | yes | GitHub PAT / fine-grained token с `contents:write` на showcase repos |
| `GITHUB_MIRROR_OWNER` | no | owner на GitHub (сейчас `xotabeach`) |

Без `GITHUB_MIRROR_TOKEN` job просто не создаётся (`rules`). Локальный
ручной прогон: `./scripts/mirror-to-github.sh` в workspace.

## Ответственность репозиториев

| Repository | Ответственность |
| --- | --- |
| `workspace` (superproject) | Точка входа, Makefile, submodule pointers, migrate/mirror scripts |
| `tourism-platform` | Docs, ADR, local Compose, `deploy/test`, будущие Helm |
| `tourism-backend` | FastAPI modular monolith, DB migrations, API, tests |
| `tourism-mobile` | Flutter Android/iOS, UI, client state |

Не перемещать файлы между repos без необходимости. Не создавать дополнительные
repositories. Не хранить secrets в Git.

## Ветки

Базовая ветка: `main`.

Короткоживущие ветки от `main`:

- `feat/<short-name>` — функциональность;
- `fix/<short-name>` — исправления;
- `docs/<short-name>` — документация;
- `chore/<short-name>` — tooling/CI;
- `refactor/<short-name>` — рефакторинг без смены поведения.

Избегать долгоживущих feature-branch. Release branches не требуются до первого
versioned staging release.

## Коммиты

Формат: [Conventional Commits](https://www.conventionalcommits.org/).

Примеры:

- `feat(places): add place detail endpoint`
- `fix(health): include redis in readiness`
- `docs: describe route execution lifecycle`
- `chore(ci): build docker image without push`

Правила:

- один логический смысл на commit;
- subject ≤ 72 символов, без точки в конце;
- на русском или английском — единообразно внутри MR; предпочтительно English
  subject для tooling, body можно на русском;
- не коммитить `.env`, ключи, dump БД, `build/`.

## Merge requests

1. MR в тот repository, где меняется код.
2. Локально: `./scripts/validate.sh` или `make validate`.
3. Описание: summary + test plan.
4. После merge в submodule — отдельный commit в `workspace` с обновлением
   pointer.
5. Не пушить force в `main`.
6. Squash допустим, если история шумная.

Порядок submodule workflow:

1. Commit + merge в `tourism-backend` / `tourism-mobile` / `tourism-platform`.
2. В workspace: `git submodule update --remote <name>` (или checkout SHA).
3. Commit pointer в workspace.

## Versioning

- Приложения: Semantic Versioning `MAJOR.MINOR.PATCH` после первого staging.
- До первого релиза допустим `0.y.z` (ломающие изменения в minor).
- Backend package version в `pyproject.toml`; mobile — `pubspec.yaml`
  `version: x.y.z+build`.
- Superproject version не обязателен; совместимость = submodule SHAs.

## API versioning

- Публичный HTTP API: prefix `/api/v1`.
- Health probes вне versioned API: `/health/live`, `/health/ready`.
- Ломающие изменения → `/api/v2` или совместимый additive change в v1.
- Контракты описываются до реализации consumers (OpenAPI из FastAPI).

## Environment naming

| Name | Назначение |
| --- | --- |
| `local` | Developer machine + Compose (`APP_ENV=local`) |
| `test` | Constrained remote test host (`APP_ENV=test`) |
| `staging` | Shared pre-production (host ещё не заведён) |
| `production` | Production (отдельный контур; GitLab env name ≠ APP_ENV) |

Переменная runtime: **`APP_ENV`** (`local` / `test` / `staging` /
`production`). Синоним `ENVIRONMENT=development` не используется в коде.

Не использовать production secrets локально. `.env.example` — только safe local
defaults. AI Gemma 4 не ставится на test-VPS: [stack.md](stack.md).

## Progress log

После завершения фазы обновляй [progress.md](progress.md): статус таблицы,
блок «Что сделано», «Что дальше», блокеры. Это короткий статус для команды;
детальный backlog остаётся в [implementation-plan.md](implementation-plan.md).

## Язык и стиль кода

- Backend: Python 3.13, Ruff, MyPy strict, Pytest —
  [python-code-style.md](python-code-style.md),
  [python-testing-guide.md](python-testing-guide.md).
- Mobile: Dart/Flutter, `flutter analyze`, tests —
  [flutter-code-style.md](flutter-code-style.md),
  [flutter-testing-guide.md](flutter-testing-guide.md).
- DX setup (uv, Cursor, Make): [development-environment.md](development-environment.md).
- Docs: Markdown, markdownlint где подключён; yamllint для CI/compose YAML.

## Архитектурные ограничения

- Modular monolith; без Kafka до подтверждённого сценария (ADR-005).
- Без service mesh и отдельного Python API Gateway.
- Одна PostgreSQL БД на контур.
- `RoutingProvider` — абстракция; реализация Phase 8A.
- LLM только за `AIPlanningProvider`; default home-lab model **`gemma4:12b`**.
- Entitlements через сервис разрешений, не `user.is_premium`.
- Не копировать код/UI legacy Android-проекта.
