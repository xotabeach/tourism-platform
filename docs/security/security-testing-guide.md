# Security testing guide

## Local commands

### Backend

```bash
cd tourism-backend
./scripts/validate.sh
uv run pytest tests/security
uv run pip-audit
uv run ruff check .
```

**Required** when changing any endpoint that accepts client/query/body input
or returns text later shown in mobile/admin: run `pytest tests/security`
before claiming the change is done.

### Mobile

```bash
cd tourism-mobile
./scripts/validate.sh
flutter test test/security/
```

**Required** when changing UI that shows API/user text, networking, or storage:
run `flutter test test/security/` plus relevant widget tests. Render untrusted
strings as text only (no HTML/WebView).

### Platform docs / compose

```bash
cd tourism-platform
./scripts/validate.sh
```

## CI DevSecOps gates (as-built)

OSS scanners (no paid GitLab Ultimate required). Fail-closed unless noted.

| Repo | Job | Gate |
| --- | --- | --- |
| backend | `backend-security-tests` | `pytest tests/security` |
| backend | `backend-pip-audit` | known Python CVEs |
| backend | `backend-gitleaks` | secret leak in git history/workdir |
| backend | `backend-semgrep` | SAST `p/python` + `p/owasp-top-ten`, ERROR only |
| backend | `backend-trivy` | image HIGH/CRITICAL (after publish; blocks deploy) |
| mobile | `mobile-gitleaks` | secret leak |
| mobile | `mobile-semgrep` | SAST `p/owasp-top-ten` + `p/secrets`, ERROR only |
| mobile | `mobile-osv` | OSV on `pubspec.lock` |
| mobile | `mobile-apk-test` | signed test APK artifact (main/gamma + CI signing vars) |
| platform | `platform-gitleaks` | secret leak |

Publish / deploy / APK jobs `needs` the security jobs above. Temporary
waivers: [exceptions/](exceptions/) (`SEC-EX-*`).

## What to test

See baseline lists in the security prompt / checklist. Minimum for current
code:

- Places search with SQL metacharacters does not break query structure.
- `limit`/`q` bounds reject oversized input.
- Unpublished places are not returned (404 / not found).
- Health and public endpoints do not require auth (expected).
- No secrets in committed files (secret scan).
- Dockerfile builds as non-root user.
- Auth/BOLA/favorites/reviews/notifications covered by `tests/security`.

## Tooling decision log

| Tool | Threat | Python/Dart | GitLab tier | Owner | FP risk | Local/CI |
| --- | --- | --- | --- | --- | --- | --- |
| Ruff + `S` rules | common insecure patterns | Python | any | backend | low–med | both |
| pip-audit | known CVEs in deps | Python | any | backend | low | both |
| MyPy / flutter analyze | type/safety hygiene | both | any | team | low | both |
| Pytest security/ | regression | Python | any | backend | low | both |
| Gitleaks | leaked secrets | any | OSS | DevSecOps | med | **CI as-built** |
| Semgrep | SAST | Python / general | OSS | DevSecOps | med | **CI as-built** (ERROR; no official Flutter pack yet) |
| OSV-Scanner | Dart lockfile CVEs | Dart | OSS | mobile | low–med | **CI as-built** |
| Trivy | image CVEs | containers | OSS | DevSecOps | med | **CI as-built** (HIGH/CRITICAL) |
| GitLab Secret Detection / SAST templates | same as above | any | Free+/Ultimate | — | med | optional if tier confirmed; OSS preferred |
| Bandit | overlapping with Ruff S | Python | OSS | backend | med | only if Ruff S insufficient |

Do not enable paid GitLab scanners blindly without confirming the group tier.
Prefer OSS equivalents when features are unavailable.

## DAST

Only against local, dedicated test, or explicitly allowed staging. Never
against production or third-party domains without authorization. Not in CI
yet (next iteration).
