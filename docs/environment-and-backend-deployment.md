# Environment and backend deployment strategy

## Purpose

Define one environment contract for mobile, backend, infrastructure, database,
and future AI providers, then deploy the first remote backend test contour to a
single existing server. Git branches, runtime environments, data sources, and
AI providers are separate concerns.

The first server is resource-constrained. It is suitable only for low-traffic
smoke testing with strict limits and swap, not for staging, production, local
AI inference, or user data. Its inventory remains outside Git.

## Environment contract

Canonical runtime environments:

| Environment | Mobile data source | Backend dependencies | AI policy |
| --- | --- | --- | --- |
| `local` | `mock` by default; `api` selectable | Local Compose | `mock` by default; provider selectable explicitly |
| `test` | Deployed app uses API; automated tests use fakes | Isolated, resettable test services | Gemini only in explicit external-provider checks; normal tests use `mock` |
| `staging` | API only | Isolated staging services and credentials | Self-hosted when available; otherwise disabled or explicitly configured Gemini |
| `production` | API only | Isolated production services and credentials | Self-hosted only when AI planning is enabled |

GitLab CD environments map to branches:

| Git branch | GitLab environment | Registry tip tag | Remote server deploy |
| --- | --- | --- | --- |
| `gamma` | `stage` | `:stage` | No — stage host not configured yet |
| `main` | `production` | `:production` | Yes — protected SSH deploy job only |

Runtime `APP_ENV` on the host is independent of the GitLab environment name and
stays configured on the server. Staging and a future dedicated production host
must use their own protected jobs and isolated infrastructure.

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

## First test server scope

The first rollout is a disposable **test** contour on one constrained server:

```text
Internet
  -> HTTPS reverse proxy
    -> tourism-backend container
      -> private PostgreSQL/PostGIS
      -> private Redis
```

Only ports `80/443` and an explicitly restricted SSH port are public.
PostgreSQL and Redis remain private. MinIO, Mailpit, AI inference, authentication
mail delivery, and production data are excluded to preserve memory and disk.
Bundled test media are served by the backend image.

Use Docker Engine and a deployment-specific Compose file for the first server.
Kubernetes and Helm remain optional future migration paths after a real need
for multi-node scheduling or independent scaling appears.

The test host requires at least 1 GB swap, one backend worker, bounded container
memory, bounded JSON logs, and regular image pruning. Swap makes smoke testing
possible but does not turn the host into a production-capable server.

## Delivery flow

1. Backend CI runs lint, type checks, tests, dependency audit, migration smoke,
   and container build.
2. On `gamma` or `main`, CI pushes an immutable image tagged with the commit
   SHA, plus a floating tip (`:stage` on `gamma`, `:production` on `main`).
3. Deploy stage:
   - `gamma` → GitLab environment `stage` (records the published image; no SSH).
   - `main` → GitLab environment `production` SSHes with a restricted non-root
     deploy identity and updates the remote server.
4. On production deploy, the server pulls the exact image, runs database
   migrations once, and recreates the backend container.
5. Deployment waits for container health (`/health/ready` inside the image),
   then optionally hits the public readiness URL.
6. Failure leaves investigation to operators; restore the previous
   `BACKEND_IMAGE` value in the server `.env` and recreate. Database rollback
   is not automatic unless the migration has an explicitly reviewed downgrade
   path.

Protected GitLab CI variables for production deploy (names only; values stay in
GitLab, never Git):

```text
DEPLOY_SSH_HOST
DEPLOY_SSH_PORT
DEPLOY_SSH_USER
DEPLOY_SSH_PRIVATE_KEY   # type: file
DEPLOY_SSH_KNOWN_HOSTS   # type: file
DEPLOY_HEALTH_URL        # optional public smoke URL
```

No source checkout, compiler toolchain, or long-lived GitLab personal token is
required on the server. Registry pulls use a server-local Docker login for the
GitLab Container Registry.

## Security and operations baseline

- Key-only SSH, non-root deployment user, host firewall, unattended security
  updates, and rate-limited public API entry point.
- TLS certificates with automatic renewal and HTTPS redirect.
- Environment-scoped masked/protected GitLab variables; server secret files
  owned by the deployment user with restrictive permissions.
- Structured logs with request correlation and retention limits.
- Disk, memory, CPU, container restart, certificate-expiry, and readiness
  alerts.
- Test database backups copied off the application server before destructive
  deployment experiments.
- A restore exercise is required before treating the contour as production.
- Document recovery point and recovery time targets after measuring the first
  backup and restore.

## Rollout stages

### Phase 5.5 - Environment foundation

- Introduce typed `APP_ENV` in backend and mobile.
- Replace the mobile mock boolean with validated `DATA_SOURCE`.
- Add startup policy tests and environment-scoped examples without secrets.
- Keep automated tests deterministic and independent from Gemini.

### Phase 5.6 - First remote test backend

- Record server inventory without secrets.
- Decide DNS names and TLS entry point.
- Add constrained deployment Compose, reverse proxy, health checks, migration
  job, backup hooks, and protected test pipeline.
- Deploy a `main` / production image to the remote host and connect a mobile
  build. Keep `gamma` / stage publish-only until a stage host exists.
- Complete deploy, rollback, backup, and restore smoke tests.

### Phase 10 - Production readiness

- Establish a properly sized staging environment before adding performance and
  security testing, observability retention, production secrets/signing,
  capacity limits, and an explicit production cutover review.
- Consider Kubernetes/Helm only when operational evidence justifies it.

## Inputs required before implementation

- Server OS/version, CPU architecture, CPU/RAM/disk, and available disk backup
  destination.
- Hosting provider/network controls and whether a public IPv4/IPv6 address is
  stable.
- Domain ownership and desired staging API hostname.
- SSH access model and whether GitLab can reach the server.
- A controlled DNS name for the test API and an off-host backup destination.

Do not place IP addresses, usernames, private hostnames, keys, tokens, or real
credentials in this document.
