# ADR-008: Narrative RAG in Postgres via pgvector

- Статус: принято (Phase 8B as-built)
- Дата: 2026-08-21
- Связано: [ADR-006](ADR-006-ai-assisted-route-planning.md),
  [ai-route-planning-architecture.md](../ai-route-planning-architecture.md)

## Контекст

Длинные narrative-тексты (история, tips, howto) не должны жить в весах модели
и не являются SoT для координат/часов/цен. Нужен retrieval рядом с PostGIS.

Ранее в docs фигурировал **Qdrant** (home lab). Для Phase 8B на том же
Postgres, где уже PostGIS, проще и безопаснее держать chunks + embeddings
в **pgvector**: один бэкап, одна authZ-граница, меньше сетевых hops на
test-VPS.

## Решение

1. Таблица `knowledge_chunks` + колонка `embedding vector(384)` + HNSW
   (миграция `0032`).
2. Образ Postgres: `crimeatrip/postgis-pgvector:16-3.4`
   (`tourism-platform/docker/postgres`) — PostGIS **и** pgvector.
3. Ingest: `scripts/ingest_knowledge.py --apply --embed` (published
   places/routes → chunks; hash-embedder v1).
4. Retrieve: `TourismKnowledgeRetriever` — cosine по pgvector, fallback FTS.
5. Chat: при `RAG_ENABLED=true` chunks попадают в `tool_context.knowledge`
   как **недоверенные DATA** (не факты часов/цен).
6. Qdrant остаётся опцией home-lab / scale-out позже; не блокирует Phase 8B.

## Альтернативы

### Qdrant-first

Гибкий ANN-стек, но отдельный сервис, сеть, бэкапы. Отложено.

### Только FTS без векторов

Проще, слабее semantic match. Оставляем как fallback.

## Последствия

- Нужен образ с `postgresql-16-pgvector`; чистый `postgis/postgis:16-3.4`
  не пройдёт `CREATE EXTENSION vector`.
- Hash-embedder — bootstrap, не semantic SOTA; смена модели без смены dim.
- RAG off по умолчанию (`RAG_ENABLED=false`) до ingest на окружении.

## Security

- Chunks = untrusted (prompt injection).
- Parameterized SQL only; allowlisted fields в DATA.
- Не класть closures/prices как единственный SoT в RAG.
