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

## What to test

See baseline lists in the security prompt / checklist. Minimum for current
code:

- Places search with SQL metacharacters does not break query structure.
- `limit`/`q` bounds reject oversized input.
- Unpublished places are not returned (404 / not found).
- Health and public endpoints do not require auth (expected).
- No secrets in committed files (secret scan).
- Dockerfile builds as non-root user.

Auth/BOLA/CSRF/file/AI tests are **planned** for the phase that introduces
the feature — do not mark them done while stubs exist.

## Tooling decision log

| Tool | Threat | Python/Dart | GitLab tier | Owner | FP risk | Local/CI |
| --- | --- | --- | --- | --- | --- | --- |
| Ruff + `S` rules | common insecure patterns | Python | any | backend | low–med | both |
| pip-audit | known CVEs in deps | Python | any | backend | low | both |
| MyPy / flutter analyze | type/safety hygiene | both | any | team | low | both |
| Pytest security/ | regression | Python | any | backend | low | both |
| GitLab Secret Detection | leaked secrets | any | Free+ | DevSecOps | med | CI if available |
| GitLab SAST | generic SAST | varies | verify tier | DevSecOps | med–high | CI if available |
| Trivy (proposed) | image CVEs | containers | OSS | DevSecOps | med | CI optional |
| Bandit | overlapping with Ruff S | Python | OSS | backend | med | only if Ruff S insufficient |

Do not enable paid GitLab scanners blindly without confirming the group tier.
Prefer OSS equivalents when features are unavailable.

## DAST

Only against local, dedicated test, or explicitly allowed staging. Never
against production or third-party domains without authorization.
