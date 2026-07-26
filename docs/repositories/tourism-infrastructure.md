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

- Первый remote `test`: constrained Docker Compose на одном сервере,
  HTTPS reverse proxy, swap и private data network.
- `staging` и `production` требуют отдельного, правильно рассчитанного
  контура.
- GitLab CI с protected deploy job, immutable image, migration, smoke и
  rollback.
- Kubernetes и Helm только после появления подтверждённой потребности в
  multi-node scheduling или независимом scaling.
- PostgreSQL/PostGIS, Redis, S3-compatible storage.
- Kafka только после ADR-005 activation.
- Точки Prometheus/Grafana/Loki/Sentry.
- Terraform на текущем этапе не добавляется.

## Связь с local Compose

Local Compose в корне `tourism-platform` остаётся developer-only и не копирует
production topology один в один.

Первый server rollout описан в
[environment-and-backend-deployment.md](../environment-and-backend-deployment.md).
