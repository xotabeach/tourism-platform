# Профиль репозитория tourism-backend

## Назначение

`tourism-backend` — FastAPI modular monolith. Private GitLab repo, submodule
superproject. Стек: [stack.md](../stack.md).

## Ответственность

- HTTP API `/api/v1` и health probes.
- Domain modules и прикладные миграции PostGIS.
- Redis, object storage adapters, optional FCM.
- SQLAdmin (`/admin`).
- Structured logs, OpenAPI, security tests.

## Вне целей

- Преждевременные микросервисы.
- Flutter source и infra manifests (они в platform).
- Cross-domain ORM imports.
- Прямой вызов Ollama из mobile.
- Secrets в Git.

## Стек

- Python 3.13, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic.
- `uv`, Ruff, MyPy, Pytest.
- Redis; MinIO локально; bundled media на test host.
- JWT + opaque refresh (ADR-007); OTP (SMS provider ещё не прод).
- AI (план): `AIPlanningProvider` — mock / Gemini / Ollama `gemma4:12b`.
- Kafka только после ADR-005.

## Интеграции

- `tourism-mobile` через OpenAPI.
- Compose/deploy контракты в `tourism-platform`.
- PostGIS, Redis; optional FCM, Gemini, Ollama.

Не ссылаться на несуществующие repos `tourism-infrastructure` /
`tourism-documentation`.

## As-built vs stub

С API: identity, geography, places, routes (в т.ч. publication + reviews),
favorites, support, notifications, admin, media.

Stub-пакеты: `route_builder`, `route_execution`, `subscriptions`.

## Поэтапный план

### Этап 1–2. Foundation и data

- [x] Private remote, Python 3.13, FastAPI, health, logs.
- [x] SQLAlchemy, Alembic, PostGIS, Ruff/MyPy/Pytest, security tests.

### Этап 3. MVP (частично)

- [x] Каталог, auth, favorites, reviews, notifications, publication +
  moderation, ranks/тп/leaderboard.
- [ ] Deterministic Route Builder (Phase 8A).
- [ ] Route execution (Phase 9).
- [ ] Achievement catalog / unlock (остаток Phase 14).
- [ ] `AIPlanningProvider` + Ollama Gemma 4 (Phase 8B / Future).

### Этап 4. Эксплуатация

- [x] Constrained test deploy (Caddy + image).
- [ ] Staging host, backup/restore drills как production-ready.
- [ ] Outbox / Kafka только после подтверждённого async flow.
