# Профиль: infrastructure assets (в tourism-platform)

Отдельный repository `tourism-infrastructure` **не создаётся**. Ниже —
ответственность future infra-контента внутри `tourism-platform`.

## Назначение

Описание и автоматизация сред, доставки и эксплуатации платформы как код в
`tourism-platform` (каталоги вроде `deploy/`, `helm/` — появятся позже).

## Ответственность

- Описывать вычислительные, сетевые и управляемые ресурсы как код.
- Настраивать `staging` и `production`.
- Автоматизировать сборку, доставку, миграции и откат (GitLab CI).
- Наблюдаемость, backup/restore hooks.
- Безопасная передача конфигурации и ссылок на секреты (не значений).

## Вне целей

- Прикладной код и доменная логика.
- Значения секретов в Git.
- Владение пользовательскими/географическими данными.
- Ручное создание неописанных ресурсов.

## Эволюция стека

- Test host **as-built**: Caddy + backend image + PostGIS + Redis
  (`deploy/test/`). Lean GitLab CI; publish + manual deploy.
- `staging` и полноценный `production` — отдельный контур, не этот VPS.
- Kubernetes/Helm только после multi-node нужды.
- Local DX: PostGIS, Redis, MinIO, Mailpit.
- **Gemma 4 / Ollama / Qdrant** — GPU home lab, не test-сервер
  ([stack.md](../stack.md)).
- Kafka только после ADR-005.
- Terraform на текущем этапе не добавляется.

## Связь с local Compose

Local Compose в корне `tourism-platform` остаётся developer-only и не копирует
production topology один в один.

Первый server rollout описан в
[environment-and-backend-deployment.md](../environment-and-backend-deployment.md).
