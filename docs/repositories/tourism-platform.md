# Профиль репозитория tourism-platform

## Назначение

`tourism-platform` — канонический repository документации, local Compose и
test-deploy assets. Application source backend/mobile здесь нет. Submodule
superproject `workspace`.

Стек: [stack.md](../stack.md).

## Ответственность

- Границы модулей, contracts, ADR.
- Local Compose: PostGIS, Redis, MinIO, Mailpit.
- `deploy/test`: Caddy + backend + PostGIS + Redis.
- Продуктовая документация и implementation plan.
- Позже: Helm, если появится multi-node нужда.
- Tooling workspace (Make, validate, clone helpers).

## Вне целей

- Микросервисы до критериев извлечения.
- Backend или Flutter source.
- Cross-module ORM imports (это правило backend).
- Выдача платформы за официальное госприложение.
- Secrets в Git.
- Ollama/Gemma на test-VPS.

## Стек (as-built + план)

- Markdown, Mermaid.
- Docker Compose local DX и constrained test host.
- Bash, PowerShell, Make.
- Документация low-minutes CI; backend deploy выполняется локальным скриптом.
- Целевой home lab: Ollama **Gemma 4** + Qdrant — документы, не этот Compose.
- Kubernetes/Helm позже **в этом** repository.

## Интеграции

- `tourism-backend` — modular monolith.
- `tourism-mobile` — потребитель API.
- Routing/geo/media/FCM/Gemini/Ollama — через адаптеры backend, не из docs repo.

## Результаты

- Документированные границы и ADR.
- Воспроизводимый local и описанный test deploy.
- Validation конфигурации.
