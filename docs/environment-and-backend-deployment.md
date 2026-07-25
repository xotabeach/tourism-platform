# Environment and backend deployment strategy

## Purpose

Define one environment contract for mobile, backend, infrastructure, database,
and future AI providers, then deploy the first backend staging contour to a
single existing server. Git branches, runtime environments, data sources, and
AI providers are separate concerns.

The first server is suitable for the application stack, but not for local AI
inference. AI deployment is therefore outside the first rollout.

## Environment contract

Canonical runtime environments:

| Environment | Mobile data source | Backend dependencies | AI policy |
| --- | --- | --- | --- |
| `local` | `mock` by default; `api` selectable | Local Compose | `mock` by default; provider selectable explicitly |
| `test` | Deployed app uses API; automated tests use fakes | Isolated, resettable test services | Gemini only in explicit external-provider checks; normal tests use `mock` |
| `staging` | API only | Isolated staging services and credentials | Self-hosted when available; otherwise disabled or explicitly configured Gemini |
| `production` | API only | Isolated production services and credentials | Self-hosted only when AI planning is enabled |

The Git branch `gamma` deploys to `staging`; `gamma` is not a runtime
environment value. Production deployment must use a protected branch or
immutable release tag.

Target configuration:

```text
APP_ENV=local|test|staging|production
DATA_SOURCE=mock|api
API_BASE_URL=https://...

AI_PLANNING_ENABLED=false
AI_PROVIDER=mock|gemini|self_hosted
AI_MODEL=...
AI_BASE_URL=...
```

Secrets such as database passwords, signing keys, and `GEMINI_API_KEY` are
environment-scoped CI/server secrets and never mobile compile-time values.

## Database and storage isolation

- Each non-local environment has separate PostgreSQL/PostGIS, Redis, object
  storage, credentials, and backup lifecycle.
- Do not share production tables by adding an `environment_id` column.
- Use one migration history for every environment.
- Run migrations as a one-shot deployment job with a dedicated migration role;
  the application runtime role receives only required DML privileges.
- Never copy production data into test or staging without an approved,
  repeatable anonymization process.

## First server scope

The first rollout is a **staging** contour on one server:

```text
Internet
  -> HTTPS reverse proxy
    -> tourism-backend container
      -> private PostgreSQL/PostGIS
      -> private Redis
      -> private S3-compatible storage
```

Only ports `80/443` and an explicitly restricted SSH port are public.
PostgreSQL, Redis, and object storage administration ports remain private.
Mailpit is local/test-only and must not be exposed as a production mail system.

Use Docker Engine and a deployment-specific Compose file for the first server.
Kubernetes and Helm remain optional future migration paths after a real need
for multi-node scheduling or independent scaling appears.

## Delivery flow

1. Backend CI runs lint, type checks, tests, dependency audit, migration smoke,
   and container build.
2. CI pushes an immutable image tagged with the commit SHA.
3. A protected staging deploy job connects using a restricted deploy identity.
4. The server pulls the exact image, runs database migrations once, and starts
   the application.
5. Deployment waits for `/health/live` and `/health/ready`, then runs a public
   API smoke test.
6. Failure restores the previous known-good image. Database rollback is not
   automatic unless the migration has an explicitly reviewed downgrade path.

No source checkout, compiler toolchain, or long-lived GitLab personal token is
required on the server.

## Security and operations baseline

- Key-only SSH, non-root deployment user, host firewall, unattended security
  updates, and rate-limited public API entry point.
- TLS certificates with automatic renewal and HTTPS redirect.
- Environment-scoped masked/protected GitLab variables; server secret files
  owned by the deployment user with restrictive permissions.
- Structured logs with request correlation and retention limits.
- Disk, memory, CPU, container restart, certificate-expiry, and readiness
  alerts.
- Encrypted database and object-storage backups copied off the application
  server.
- A restore exercise is required before treating the contour as production.
- Document recovery point and recovery time targets after measuring the first
  backup and restore.

## Rollout stages

### Phase 5.5 - Environment foundation

- Introduce typed `APP_ENV` in backend and mobile.
- Replace the mobile mock boolean with validated `DATA_SOURCE`.
- Add startup policy tests and environment-scoped examples without secrets.
- Keep automated tests deterministic and independent from Gemini.

### Phase 5.6 - First backend server deployment

- Record server inventory without secrets.
- Decide DNS names and TLS entry point.
- Add deployment Compose, reverse proxy, health checks, migration job, backup
  hooks, and protected staging pipeline.
- Deploy `gamma` as staging and connect a staging mobile build.
- Complete deploy, rollback, backup, and restore smoke tests.

### Phase 10 - Production readiness

- Add performance and security testing, observability retention, production
  secrets/signing, capacity limits, and an explicit production cutover review.
- Consider Kubernetes/Helm only when operational evidence justifies it.

## Inputs required before implementation

- Server OS/version, CPU architecture, CPU/RAM/disk, and available disk backup
  destination.
- Hosting provider/network controls and whether a public IPv4/IPv6 address is
  stable.
- Domain ownership and desired staging API hostname.
- SSH access model and whether GitLab can reach the server.
- Expected initial traffic, acceptable deployment downtime, and backup
  retention.

Do not place IP addresses, usernames, private hostnames, keys, tokens, or real
credentials in this document.
