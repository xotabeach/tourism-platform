# Профиль репозитория tourism-platform

## Назначение

`tourism-platform` — канонический repository документации, локальной
инфраструктуры и будущих staging/production assets (Kubernetes/Helm). Он не
содержит application source backend/mobile. Подключается как submodule
superproject `workspace`.

## Ответственность

- Описывать границы модулей, contracts и правила зависимостей.
- Предоставлять единые команды запуска, проверки и локальной разработки.
- Содержать local Compose для PostgreSQL/PostGIS, Redis, MinIO и Mailpit.
- Хранить продуктовую документацию, ADR и implementation plan.
- В будущем: Helm charts, env configs, observability wiring.
- Предоставлять tooling для multi-repository workspace.

## Вне целей

- Создание отдельных микросервисов до появления критериев извлечения.
- Хранение backend или Flutter source.
- Прямая зависимость одного модуля от ORM-моделей другого.
- Выдача платформы за официальное государственное приложение.
- Хранение production secrets в Git.

## Будущая реализация и стек

- Markdown и Mermaid для документации.
- Docker Compose для local dependencies.
- Bash, PowerShell и Make для developer workflow.
- GitLab CI для validation без deployment.
- Kubernetes/Helm позже **в этом** repository (отдельный
  `tourism-infrastructure` repo не создаётся).

## Интеграции

- `tourism-backend` — modular monolith.
- `tourism-mobile` — потребитель API.
- Внешние routing/geo/media провайдеры через адаптеры.

## Результаты

- Документированные границы и architecture decisions.
- Воспроизводимое локальное окружение.
- Validation конфигурации и управляющих файлов.
