# Container diagram

Два слоя: **as-built** (local DX и test host) и **целевой home lab**
(Gemma 4). Это не одна Compose-файл. Сводка: [stack.md](../stack.md).

Kafka — ADR-005, не включена. Kubernetes Ingress — будущая topology, не local.

## As-built: local DX

`compose.yaml`: PostGIS, Redis, MinIO, Mailpit. Backend и Flutter на хосте.

```mermaid
flowchart LR
    Traveler[Путешественник]
    Flutter["Flutter Mobile"]
    Admin["SQLAdmin /admin"]

    subgraph local [Developer machine]
        Backend["Backend FastAPI"]
        PostgreSQL["PostgreSQL / PostGIS"]
        Redis["Redis"]
        Storage["MinIO"]
        Mailpit["Mailpit"]
    end

    Traveler --> Flutter
    Flutter -->|HTTP JSON local/test| Backend
    Admin -->|cookie session| Backend
    Backend --> PostgreSQL
    Backend --> Redis
    Backend --> Storage
    Backend --> Mailpit
```

## As-built: test host

`deploy/test/compose.yaml`. Нет MinIO, Mailpit, Ollama.

```mermaid
flowchart LR
    Traveler[Путешественник]
    Flutter["Flutter Mobile"]
    Caddy["Caddy TLS"]
    Backend["Backend FastAPI"]
    PostgreSQL["PostgreSQL / PostGIS"]
    Redis["Redis"]
    FCM["FCM HTTP v1"]

    Traveler --> Flutter
    Flutter -->|HTTPS| Caddy
    Caddy --> Backend
    Backend --> PostgreSQL
    Backend --> Redis
    Backend -.->|optional tray| FCM
```

## Target: AI home lab (не реализовано в коде)

Отдельная GPU-машина. Bind только `127.0.0.1`. Не ставить на test-VPS.
Фрагмент Compose: [ai-self-hosted-home-lab.md](../ai-self-hosted-home-lab.md).

```mermaid
flowchart LR
    Flutter["Flutter"]
    Backend["FastAPI AIPlanningProvider"]
    PostgreSQL["PostGIS SoT"]
    Ollama["Ollama gemma4:12b"]
    Qdrant["Qdrant RAG Future"]

    Flutter -->|HTTPS only| Backend
    Backend --> PostgreSQL
    Backend --> Ollama
    Backend -.-> Qdrant
```
