# Production backend deploy runbook

This runbook is the source of truth for deploying the backend without GitLab
shared-runner minutes. Run commands from the trusted Mac workspace; never copy
production secrets into Git, chat, command output, or documentation.

## What is deployed

Both supported flows build the current backend commit for `linux/amd64` and use
an immutable image name:

```text
registry.gitlab.com/travel-platform2/tourism-backend:<full-git-sha>
```

The server then updates `BACKEND_IMAGE`, starts PostgreSQL and Redis, runs the
Alembic migrations once, recreates only the backend container, and waits for
container health. The SSH alias `crimeatrip-test` in `~/.ssh/config` pins the
host, non-standard port `6579`, user and identity file.

## Preflight

```bash
cd /Users/nikita/mobile_travel_app/tourism-backend
git status --short --branch
git rev-parse HEAD
./scripts/validate.sh
docker info
ssh crimeatrip-test 'true'
```

Deploy only a reviewed clean commit that has already been pushed. Do not deploy
with uncommitted backend changes.

## Preferred flow: GitLab Container Registry

Use this when Docker has valid write access to `registry.gitlab.com`. Provide
the required registry and pinned-SSH variables through the operator's password
manager or shell, then run:

```bash
cd /Users/nikita/mobile_travel_app/tourism-backend
./scripts/deploy-production-local.sh
```

This builds and pushes the full-SHA and `production` tags, then invokes the
server deploy script. A `401` or `403` from the registry means authentication
must be renewed; it is not evidence that the server was updated.

## Fallback flow: direct pinned-SSH transfer

Use this when GitLab Registry credentials are expired or unavailable. It still
uses an immutable full-SHA image, but loads it directly into Docker on the
server instead of publishing/pulling it through the registry:

```bash
cd /Users/nikita/mobile_travel_app/tourism-backend
./scripts/deploy-production-direct.sh
```

The script:

1. builds `linux/amd64` with Docker Buildx and `--load`;
2. streams `docker save | gzip` over the pinned `crimeatrip-test` SSH alias;
3. makes the server verify that the exact image exists locally;
4. runs the same migration, recreate and readiness sequence with pull skipped.

The server copy of `deploy-remote.sh` must support `DEPLOY_SKIP_PULL=true`. When
that infrastructure script changes, install the reviewed source-of-truth copy:

```bash
cd /Users/nikita/mobile_travel_app
scp tourism-platform/deploy/test/deploy-remote.sh \
  crimeatrip-test:/opt/crimeatrip-test/deploy-remote.sh
ssh crimeatrip-test 'chmod 755 /opt/crimeatrip-test/deploy-remote.sh'
```

Do not use `DEPLOY_SKIP_PULL=true` unless the image was transferred immediately
beforehand. The remote script fails closed if that exact image is absent.

## Required verification

After either flow, all checks must pass:

```bash
curl --fail --silent --show-error \
  https://86-106-20-132.sslip.io/health/live
curl --fail --silent --show-error \
  https://86-106-20-132.sslip.io/health/ready
```

Also smoke-test at least one endpoint introduced or changed by the deployed
commit. For a schema change, confirm the feature endpoint rather than relying
only on health: an older healthy container can still return `404` for the new
API.

On the server, the active immutable image can be checked without exposing
secrets:

```bash
ssh crimeatrip-test \
  "docker inspect --format='{{.Config.Image}}' crimeatrip-test-backend-1"
```

## Rollback

Read the previous `BACKEND_IMAGE` value from deployment output. To roll back,
run the server deploy script with that exact previous immutable image. Registry
flow pulls it normally; direct flow requires the image to still exist in the
server Docker cache before using `DEPLOY_SKIP_PULL=true`.

Database rollback is never automatic. If the failed release ran a migration,
review migration compatibility first; do not run `alembic downgrade` without a
separately reviewed recovery plan and backup.
