# CI modes and runners

How we avoid GitLab shared-runner usage while the August 2026 minute quota is
low, and how to bring back automated checks with a self-hosted runner later.

## Current low-minutes mode

Backend push pipelines are disabled completely. A regular push therefore uses
zero GitLab runner minutes and does not publish or deploy anything.

### Which repositories still spend minutes on push (2026-08-24)

Only the backend is fully disabled. The other three **do** create a pipeline
on a normal push, which is easy to miss:

| Репозиторий | `workflow.rules` | Пуш в `main` тратит минуты? |
| --- | --- | --- |
| `tourism-backend` | только `CI_PIPELINE_SOURCE == "web"` | нет |
| `tourism-mobile` | `CI_COMMIT_BRANCH == "main" \|\| "gamma"` | **да** |
| `tourism-platform` | `CI_COMMIT_BRANCH == "main" \|\| "gamma"` | **да** |
| `workspace` (корень) | **нет `workflow:` вообще** | **да, на любой пуш** |

While the quota is low, push to those three with the GitLab push option that
skips pipeline creation:

```bash
git push -o ci.skip origin main
```

`-o ci.skip` prevents the pipeline from being created at all (it is not a
cancelled or skipped job that still bills). The GitHub mirror remote is
unaffected either way.

Longer-term the honest fix is to give `tourism-mobile`, `tourism-platform`
and `workspace` the same `web`-only `workflow.rules` the backend has, so
skipping is not something an operator has to remember on every push.

The backend `.gitlab-ci.yml` keeps one escape hatch: a pipeline created
manually through **Build → Pipelines → Run pipeline** exposes a manual
`backend-publish-manual` job. It builds and pushes the registry image only;
it does not SSH to production.

Normal production delivery now runs from a trusted developer machine:

```bash
cd tourism-backend
./scripts/deploy-production-local.sh
```

The complete operator flow, verification, rollback, and the direct pinned-SSH
fallback for expired Registry credentials are documented in
[`production-backend-deploy-runbook.md`](production-backend-deploy-runbook.md).

This builds a `linux/amd64` image, pushes immutable `:<git-sha>` and
`:production` tags, and reuses the pinned-host-key SSH deploy script. It
consumes no GitLab minutes. Required values are injected only into the local
shell and never committed:

```text
CI_REGISTRY_USER
CI_REGISTRY_PASSWORD
DEPLOY_SSH_HOST
DEPLOY_SSH_PORT
DEPLOY_SSH_USER
DEPLOY_SSH_PRIVATE_KEY
DEPLOY_SSH_KNOWN_HOSTS
DEPLOY_HEALTH_URL          # optional
```

`DEPLOY_SSH_PRIVATE_KEY` and `DEPLOY_SSH_KNOWN_HOSTS` are paths to local files,
not pasted key bodies. Use `--import-osm-crimea` only for an intentional OSM
import after deployment.

### Local quality gates (mandatory in lean mode)

CI does not block merge on style/tests. Before push / before claiming work
done, run in the touched repo:

```bash
# backend
cd tourism-backend && ./scripts/validate.sh

# mobile
cd tourism-mobile && ./scripts/validate.sh

# platform docs / compose
cd tourism-platform && ./scripts/validate.sh
```

Agent workflow: Cursor skill `travel-platform-local-ci` and workspace rule —
the agent must run these (or equivalent commands) for changed surfaces and
must not claim they passed without running them.

Security-sensitive changes: still follow
[security/secure-development-lifecycle.md](security/secure-development-lifecycle.md)
and run `pytest tests/security` / `flutter test test/security` as applicable.
Run the full local validation set before a production release.

## Shared-runner minutes

GitLab SaaS bills **sum of job durations** (parallel jobs add up). Failed and
retried pipelines still consume the quota. When the namespace hits 0 minutes,
no new jobs run until the period resets, minutes are purchased, or a
self-hosted runner is used.

Backend pushes do **not** start pipelines on any branch. A manual web pipeline
still spends minutes, so it is an emergency registry-build fallback, not the
default deploy path. Automatic GitHub mirroring is also paused in this mode.

## Self-hosted runner

Yes — you can register your own GitLab Runner so jobs do not use the shared
minute pool.

### Prefer a dedicated small VM, not the production app host

Running a runner on the **same server that serves production** is possible
but discouraged:

- CI jobs pull arbitrary images and execute repo scripts (supply-chain risk).
- Docker/`privileged` / DinD jobs weaken isolation next to live traffic and
  secrets.
- A compromised dependency or malicious MR can reach the prod host.

Recommended: cheap separate VPS (or a home lab box) with only `gitlab-runner`
and Docker; no production `.env`, no deploy SSH private keys on that machine
unless you intentionally isolate a **deploy** runner with tags.

### Register a runner (outline)

1. Create a small VM; install Docker Engine and
   [GitLab Runner](https://docs.gitlab.com/runner/install/).
2. In GitLab: group or project → **Settings → CI/CD → Runners → New project
   runner** → copy the authentication token.
3. On the VM:

   ```bash
   sudo gitlab-runner register
   # URL: https://gitlab.com/
   # Token: from the UI
   # Executor: docker
   # Default image: alpine:3.21  (jobs override image anyway)
   ```

4. Tag the runner (e.g. `self-hosted`) and optionally set
   `tags: [self-hosted]` on jobs, or make it the group default and disable
   shared runners on the group when ready.
5. Lock the runner to your group; do not enable it for public forks.

If automatic deploy returns later, its SSH job should use a **separate** runner
tag and minimal privileges.

### Until a runner exists

Use local `./scripts/validate.sh` and the explicit local deploy command. Buy
extra compute minutes only if a manual registry build is genuinely needed
before a self-hosted runner is ready.

## Related docs

- [security/security-testing-guide.md](security/security-testing-guide.md) —
  scanner inventory for local/re-enabled CI gates
- [environment-and-backend-deployment.md](environment-and-backend-deployment.md)
  — production deploy variables
- [mobile-build-and-install.md](mobile-build-and-install.md) — CI APK artifact
