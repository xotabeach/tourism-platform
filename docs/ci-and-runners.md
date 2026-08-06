# CI modes and runners

How we use GitLab CI while shared-runner minutes are limited, and how to
bring back the full DevSecOps pipeline or a self-hosted runner later.

## Two pipeline modes

| Mode | When | What runs on GitLab shared runners |
| --- | --- | --- |
| **Lean** (default) | Active day-to-day development | Tiny notice job; backend image publish + manual production deploy; optional manual mobile APK; GitHub mirror |
| **Full** | Major releases / security push / when minutes allow | Style, tests, gitleaks, Semgrep, pip-audit/OSV, Trivy, APK on main/gamma, then publish/deploy |

Per-repo files:

- `.gitlab-ci.yml` — lean entrypoint + `include` of full when enabled
- `.gitlab-ci.full.yml` — archived full DevSecOps definition

### Switch to full mode

GitLab → group `travel-platform2` or a project → **Settings → CI/CD →
Variables** → add:

| Key | Value | Notes |
| --- | --- | --- |
| `CI_PIPELINE_MODE` | `full` | Unset or any other value → lean |

Remove or clear the variable to return to lean. You can also set it only on
`main` / protected branches if you want lean everywhere else.

### Local quality gates (mandatory in lean mode)

CI no longer blocks merge on style/tests. Before push / before claiming work
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
Prefer enabling **full** CI once before a production release.

## Shared-runner minutes

GitLab SaaS bills **sum of job durations** (parallel jobs add up). Failed and
retried pipelines still consume the quota. When the namespace hits 0 minutes,
no new jobs run until the period resets, minutes are purchased, or a
self-hosted runner is used.

Lean mode exists to keep deploy/APK/mirror possible without burning the
quota on every push. Feature-branch pushes do **not** start lean pipelines
(only `main` / `gamma`, manual web/API pipelines, or `CI_PIPELINE_MODE=full`).

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
+ Docker, no production `.env`, no deploy SSH private keys on that machine
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

Deploy jobs that SSH to production should use a **separate** runner tag and
minimal privileges (or stay on GitLab shared runners with protected
variables only on `main`).

### Until a runner exists

Stay on **lean** CI + local `./scripts/validate.sh`. Buy extra compute
minutes in GitLab if you need full mode before a self-hosted runner is
ready.

## Related docs

- [security/security-testing-guide.md](security/security-testing-guide.md) —
  scanner inventory (applies in full mode)
- [environment-and-backend-deployment.md](environment-and-backend-deployment.md)
  — production deploy variables
- [mobile-build-and-install.md](mobile-build-and-install.md) — CI APK artifact
