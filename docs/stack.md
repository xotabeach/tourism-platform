# Стек платформы

Канонический обзор технологий **как есть** и **как планируется**. Живой статус
фич — [progress.md](progress.md). Инференс Gemma — подробно в
[ai-self-hosted-home-lab.md](ai-self-hosted-home-lab.md).

**Последнее обновление:** 2026-08-19.

## Репозитории

Четыре GitLab-репозитория, workspace — superproject. Отдельных
`tourism-infrastructure` / `tourism-documentation` нет.

| Репозиторий | Роль |
| --- | --- |
| `workspace` | Makefile, submodule pointers, вход в docs |
| `tourism-platform` | Docs, ADR, local Compose, `deploy/test` |
| `tourism-backend` | FastAPI modular monolith, Alembic, SQLAdmin |
| `tourism-mobile` | Flutter Android/iOS |

## Что крутится сегодня

Три контура. Нейронка **не** входит ни в local Compose, ни в test-сервер.

### 1. Local DX (`tourism-platform/compose.yaml`)

Только зависимости. Backend и Flutter запускаются на хосте.

| Сервис | Образ / стек | Host port (default) |
| --- | --- | --- |
| PostgreSQL + PostGIS + pgvector | `crimeatrip/postgis-pgvector:16-3.4` (build: `docker/postgres`) | `127.0.0.1:5433` |
| Redis | `redis:8.2-alpine` | `127.0.0.1:6380` |
| MinIO | S3-compatible media | `127.0.0.1:9000` / `:9001` |
| Mailpit | SMTP catcher | `127.0.0.1:1025` / `:8025` |

Backend: Python 3.13, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, `uv`,
Ruff, MyPy, Pytest. Модули: `identity`, `geography`, `places`, `routes`,
`favorites`, `support`, `notifications`, `admin`, `media`. Пакеты-заглушки
(ещё без API): `route_builder`, `route_execution`, `subscriptions`, `users`.

Mobile: Flutter, Riverpod, GoRouter, Dio, `flutter_secure_storage`.
`DATA_SOURCE=mock` по умолчанию; `api` — к локальному/test backend.

Ops-admin: SQLAdmin на `/admin` (cookie session, не mobile JWT).

Push: in-app inbox всегда; FCM HTTP v1 опционально (Android tray).

Kafka и Kubernetes **не** в текущем стеке (ADR-005 / later).

### 2. Test-сервер (`tourism-platform/deploy/test/`)

Один constrained host. Публично только `80/443` (+ ограниченный SSH).

```text
Internet → Caddy (TLS)
  → tourism-backend (FastAPI, 1 worker)
    → PostGIS (private)
    → Redis (private)
```

Нет на этом хосте: MinIO, Mailpit, Ollama, Qdrant, Kafka. Медиа — в image /
volume backend. FCM требует исходящий HTTPS с backend (сеть `edge`).

Детали без IP/секретов:
[environment-and-backend-deployment.md](environment-and-backend-deployment.md).

### 3. CI

Backend push pipelines временно отключены полностью для экономии GitLab
minutes. Стиль, типы, тесты — локально `./scripts/validate.sh`, production
deploy — `tourism-backend/scripts/deploy-production-local.sh`. Mobile APK
остаётся отдельным manual job.
См. [ci-and-runners.md](ci-and-runners.md).

---

## Целевой AI-стек (Gemma 4, ещё не в Compose)

Планирование маршрутов с LLM — **Phase 8B+**. Сначала deterministic builder
(Phase 8A). Код адаптеров Gemini/Ollama **ещё не вшит** в backend; env в
`.env.example` — заготовки.

Порядок провайдеров (`AIPlanningProvider`):

```text
mock  →  Gemini (experimental, hosted)  →  Ollama + Gemma 4 (home lab)
```

RAG (Qdrant) — отдельно, после стабильного adapter. PostGIS остаётся SoT для
координат, часов, closures, цен. Веса модели ≠ база знаний Крыма.

### Home lab (GPU-машина, не test-сервер)

Ориентир: Linux + NVIDIA, ~12 GB VRAM (например RTX 5070). Test-VPS для
инференса **не** использовать.

| Сервис | Роль | Host bind |
| --- | --- | --- |
| LM Studio на Windows | выбранный chat/reasoning transport | `127.0.0.1:1234` |
| Ollama | альтернативный chat + embeddings transport | `127.0.0.1:11434` |
| Qdrant | Vector RAG (Future) | `127.0.0.1:6333` |
| tourism-backend | Оркестратор, validation, fallback | как сейчас |

Mobile **не** ходит в LM Studio/Ollama. Только HTTPS backend.

### Модели (Gemma 4 only)

Не откатываться на Gemma 2/3 «чтобы влезло».

| Роль | Модель | Когда |
| --- | --- | --- |
| Выбранный Windows planning | **Unsloth Gemma 4 26B A4B it UD-IQ4_XS** | LM Studio; hybrid VRAM/RAM |
| Fallback / A-B baseline | `gemma4:12b` (Q4/Q5) | если latency 26B неприемлема |
| Smoke | `gemma4:e4b` | отладка adapter |
| Quality probe | `gemma4:26b` Q4 | если влезает VRAM и latency |
| Embeddings | `nomic-embed-text` или `bge-m3` | RAG; можно CPU |

Env (когда появится код):

```text
AI_PLANNING_ENABLED=false
AI_PROVIDER=mock|gemini|ollama
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_CHAT_MODEL=gemma4:12b
OLLAMA_EMBED_MODEL=nomic-embed-text
QDRANT_URL=http://127.0.0.1:6333
RAG_ENABLED=false
```

LM Studio-вариант:

```text
AI_PROVIDER=lmstudio
LM_STUDIO_BASE_URL=http://<PRIVATE_WINDOWS_IP>:1234/v1
LM_STUDIO_MODEL=<id из /v1/models>
LM_STUDIO_API_KEY=<secret>
```

Точная Windows-инструкция:
[ai-lm-studio-windows-gemma4.md](ai-lm-studio-windows-gemma4.md).

Compose-фрагмент Ollama/Qdrant, PostGIS vs RAG, Lab-0…5:
[ai-self-hosted-home-lab.md](ai-self-hosted-home-lab.md).
Контракт planner: [ai-route-planning-architecture.md](ai-route-planning-architecture.md).

---

## Сводка «есть / нет»

| Компонент | Local | Test host | Home lab (план) |
| --- | --- | --- | --- |
| PostGIS | да | да | да (тот же SoT) |
| Redis | да | да | да |
| MinIO | да | нет | по необходимости |
| Mailpit | да | нет | нет |
| Caddy / TLS | нет | да | опционально |
| SQLAdmin | да | да | да |
| FCM | опционально | опционально | — |
| Ollama + Gemma 4 | нет | **нет** | целевой |
| Qdrant | нет | нет | после adapter |
| Kafka / Helm | нет | нет | не default |

---

## Связанные документы

- [local-development.md](local-development.md) — `make up`, порты
- [environment-and-backend-deployment.md](environment-and-backend-deployment.md)
- [ci-and-runners.md](ci-and-runners.md)
- [diagrams/container-diagram.md](diagrams/container-diagram.md)
- [decisions/ADR-006-ai-assisted-route-planning.md](decisions/ADR-006-ai-assisted-route-planning.md)
