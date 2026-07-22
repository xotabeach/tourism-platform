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

## Будущий стек

- Kubernetes и Helm для `staging` / `production`.
- Ingress как API entry point.
- GitLab CI без uncontrolled production deploy на foundation.
- PostgreSQL/PostGIS, Redis, S3-compatible storage.
- Kafka только после ADR-005 activation.
- Точки Prometheus/Grafana/Loki/Sentry.
- Terraform на текущем этапе не добавляется.

## Связь с local Compose

Local Compose в корне `tourism-platform` остаётся developer-only и не копирует
production topology один в один.
