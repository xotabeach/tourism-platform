# Backend code review

Date: 2026-07-25  
Repository: `tourism-backend`  
Reviewed revision: `cd729e5` (`main`)  
Review mode: read-only; no production code was changed during the review

## Remediation status

Implemented on backend branch `gamma` after this report was completed:

- `c9020b9` — stable readiness/validation errors, dependency timeouts, public
  route publication invariant, deterministic pagination and lifespan cleanup;
- `79413ff` — batched PostGIS coordinate queries;
- `ddf9a70` — CI integration dependencies fail closed and coverage floor is 75%.

The broad application/infrastructure boundary refactor and route filter enums
remain planned. Runtime execution of Postgres/Redis integration tests remains
pending because the local Docker daemon was unavailable.

## Executive summary

The backend has a small, understandable public API surface and strong baseline
tooling: strict MyPy, Ruff security rules, dependency auditing, bounded list
parameters, parameterized SQLAlchemy queries, and stable application error
envelopes.

The review found two high-severity security issues and five medium-severity
correctness, performance, and quality-gate issues. The most important defect is
that a public editorial route can expose unpublished place data through its
stops and cover image. The readiness endpoint also returns raw database or Redis
exception text to unauthenticated clients.

No critical (`P0`) issue was found in the implemented public read-only scope.
Authentication, authorization, uploads, payments, and write APIs are not
implemented and therefore were not reviewed as active attack surfaces.

## Findings

### P1 - Public route details can expose unpublished places

**Evidence**

- `src/tourism_backend/modules/routes/application/service.py:146` loads every
  `RouteStop` and joins `Place` only by foreign key.
- `src/tourism_backend/modules/routes/application/service.py:154` does not
  require `Place.publication_status == "published"`.
- `src/tourism_backend/modules/routes/application/service.py:160` serializes
  the place id, name, slug, and coordinates to the public response.
- `src/tourism_backend/modules/routes/application/service.py:40` selects a
  route cover from stop place images without checking place publication state.
- `src/tourism_backend/modules/routes/infrastructure/models.py:86` allows a
  route stop to reference any existing place; there is no database publication
  invariant.

**Impact**

A public active editorial route that accidentally references a draft,
unpublished, or embargoed place discloses its identity, coordinates, and cover
asset. This violates the documented publication invariant used by the public
places API.

**Required remediation**

Filter stop and cover queries to published places, define the intended behavior
for an invalid public route, and add a regression test with a public route that
references an unpublished place. Prefer rejecting the whole route as not found
or invalid rather than silently returning an incomplete itinerary.

### P1 - Readiness probes disclose internal dependency exceptions

**Evidence**

- `src/tourism_backend/api/health.py:32` catches the database exception and
  returns `f"database: {exc}"`.
- `src/tourism_backend/api/health.py:40` does the same for Redis.
- The readiness routes are public at `/health/ready` and `/ready`.

**Impact**

Driver exceptions can include hostnames, ports, database names, connection
details, filesystem paths, and operational topology. Returning them violates
the documented rule that client-facing errors contain no SQL, paths,
environment details, or stack information.

**Required remediation**

Log the exception server-side with the dependency name, return a stable generic
status to the client, and add explicit dependency timeouts plus regression tests
that assert secret exception text is absent.

### P2 - Validation responses reflect raw untrusted input

**Evidence**

- `src/tourism_backend/api/errors.py:63` returns `exc.errors()` unchanged.
- A local request with `limit=SECRET_VALUE` returned the value verbatim under
  `error.details[0].input`.

**Impact**

Request values are copied into responses and potentially into downstream logs.
This is unnecessary reflection today and becomes a secret-disclosure risk when
credentials, tokens, or personal data are later accepted by validated
endpoints.

**Required remediation**

Build a stable validation detail DTO containing only safe fields such as
`type`, `loc`, and `msg`. Add a regression test proving that submitted input is
not returned.

### P2 - Geography and place list endpoints execute N+1 coordinate queries

**Evidence**

- `src/tourism_backend/modules/geography/application/service.py:56` queries
  region coordinates once per region.
- `src/tourism_backend/modules/geography/application/service.py:72` queries
  locality coordinates once per locality.
- `src/tourism_backend/modules/places/application/service.py:115` queries
  coordinates once per place, up to the public limit of 100.

**Impact**

List latency and database load grow linearly with the result size. The places
endpoint performs the list/count/category/cover queries plus as many as 100
additional coordinate round trips.

**Required remediation**

Select `ST_X` and `ST_Y` in the main list query and serialize rows in one pass.
Add query-count or repository-level regression coverage.

### P2 - Offset pagination is not deterministically ordered

**Evidence**

- `src/tourism_backend/modules/places/application/service.py:109` orders only
  by `Place.name`.
- `src/tourism_backend/modules/routes/application/service.py:127` orders only
  by `Route.name`.
- Names are not unique; only `(region_id, slug)` is unique.

**Impact**

Rows with equal names can move between pages, creating duplicates or omissions
between requests even when data is unchanged.

**Required remediation**

Add a unique tie-breaker, for example `order_by(name, id)`, and cover duplicate
names in pagination tests.

### P2 - Integration and security tests fail open when dependencies are absent

**Evidence**

- `tests/test_places_integration.py:35`,
  `tests/test_routes_integration.py:38`, and
  `tests/security/test_public_api_security.py:60` call `pytest.skip` whenever
  either Postgres or Redis is unavailable.
- The current local validation reported `10 passed, 23 skipped`.
- `pyproject.toml:101` sets `--cov-fail-under=0`, so the coverage gate cannot
  fail.

**Impact**

A CI environment with a broken Redis service can still report a green test
command while all database-backed API and security regressions are skipped.
The displayed 77% coverage is not enforced and excludes the intended integration
paths.

**Required remediation**

Allow local opt-in skipping, but require dependencies in CI and fail when they
are missing. Add a marker/profile for integration tests and set an initial,
ratcheted coverage threshold after the tests run reliably.

### P2 - Application services directly depend on persistence implementations

**Evidence**

- `modules/geography/application/service.py:1` imports GeoAlchemy, SQLAlchemy,
  `AsyncSession`, and infrastructure models.
- `modules/places/application/service.py:3` does the same.
- `modules/routes/application/service.py:3` does the same.

**Impact**

This contradicts the repository's documented
presentation-to-application-to-domain boundary. Business use cases are tightly
coupled to SQLAlchemy and PostGIS, making isolated tests and future provider or
storage changes expensive.

**Required remediation**

Introduce application-facing repository protocols and move SQLAlchemy queries
to infrastructure adapters incrementally. This is a broader architectural
change and should not be mixed into the security hotfix.

### P3 - Lifespan cleanup is not protected by `finally`

**Evidence**

- `src/tourism_backend/main.py:27` yields and closes Redis/SQLAlchemy only in
  straight-line code after the yield.

**Impact**

If an exception is thrown into the lifespan context during shutdown, cleanup
can be skipped, leaking connections until process termination.

**Required remediation**

Wrap the yield in `try/finally` and test that both resources close when the
lifespan body exits exceptionally.

### P3 - Route filter values are unconstrained strings

**Evidence**

- `modules/routes/presentation/router.py:16` accepts arbitrary bounded strings
  for `transport_mode` and `difficulty`.

**Impact**

Typos and unsupported values return an empty successful catalog instead of a
contract error, weakening API discoverability and validation.

**Required remediation**

Use shared `StrEnum` or `Literal` values aligned with the database and API
schema.

## Positive controls observed

- Public place and route list limits are bounded.
- Query construction uses SQLAlchemy expressions rather than interpolated SQL.
- Unhandled exceptions are logged server-side and mapped to a generic 500 body.
- Production settings reject known local placeholder credentials.
- Ruff includes Bandit security checks and MyPy runs in strict mode.
- `pip-audit` is configured as a failing CI job.
- Public place details correctly reject non-published places.
- Database uniqueness constraints protect primary entrances and active covers.

## Verification performed

| Command/check | Result |
| --- | --- |
| `./scripts/validate.sh` | Passed static gates; `10 passed, 23 skipped`; total coverage reported as 77% |
| Ruff check and format check | Passed |
| MyPy strict | Passed for 48 source files |
| `pip-audit` | No known vulnerabilities; local project package is not on PyPI |
| Manual malformed-query request | Confirmed raw `input: SECRET_VALUE` in the 422 response |
| `docker compose up -d postgres redis` | Not executed successfully because Docker daemon was unavailable |
| Integration/security test review | Statically reviewed; runtime execution remains pending |

## Review limitations

- Postgres/PostGIS and Redis were unavailable locally, so all 23 integration and
  database-backed security tests were skipped.
- No authenticated, mutating, upload, payment, or route-generation APIs exist
  in the reviewed revision.
- This report does not claim production penetration testing or load testing.
