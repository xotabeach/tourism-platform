# Python testing guide

For `tourism-backend`. Runner: Pytest + pytest-asyncio (`asyncio_mode = auto`).

## Pyramid

1. **Unit** — pure domain/application logic, no network/FS/DB.
2. **Application service** — with fakes for ports.
3. **Repository / PostGIS integration** — real Postgres from Compose/CI.
4. **API integration** — httpx/ASGI client against app + DB where needed.
5. **Contract** — schema/OpenAPI smoke (lightweight).

Few e2e; many fast unit tests.

## Naming

```text
test_<behavior>_when_<condition>_<expected_result>
```

Example: `test_list_places_when_region_missing_returns_empty_page`

## Structure

Arrange / Act / Assert. Prefer parametrize over copy-paste.

## Boundaries

- Mock external systems via interfaces (`RoutingProvider`, Redis if needed).
- Do not mock Pydantic models or trivial domain objects.
- Repositories: prefer real PostGIS in integration tests (see CI services).
- Unit tests: no network, no real Redis/Postgres.

## Async

- `async def test_...` with pytest-asyncio.
- No `sleep` for waiting; use events/fakes.
- Time: inject clock or freeze; do not depend on wall clock.

## Isolation

- DB tests: transaction rollback or truncate strategy consistent per suite.
- Control UUID/random when asserting ids.

## Failure paths

Always cover typed failure codes / 4xx mapping, not only happy path.
Bug fixes get a regression test.

## Coverage

`pytest-cov` is available for local/CI **report**. There is **no fail-under
threshold** yet — avoid gaming coverage. A future soft floor (~40–50% on
`tourism_backend` packages) can be added after Phase 4–6 stabilize.

```bash
uv run pytest --cov=tourism_backend --cov-report=term-missing
```

## Commands

```bash
uv run pytest
uv run pytest tests/test_places_integration.py -q
./scripts/validate.sh
```
