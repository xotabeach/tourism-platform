# Security audit — 2026-07-23

## Scope

Whole workspace foundation (pre–Phase 4), with focus on:

- `tourism-platform` docs, Compose, SECURITY.md
- `tourism-backend` API, config, Dockerfile, CI
- `tourism-mobile` config, Dio, storage dependency
- Cursor security rule / skill / command

Branch/commit: local working tree (not pushed). Auth not implemented.

## Tools and commands

| Command | Result |
| --- | --- |
| `tourism-platform/scripts/validate.sh` | OK (compose config OK; markdownlint/yamllint skipped if missing) |
| `uv run ruff check .` (backend) | All checks passed |
| `uv run ruff format --check .` | OK after format of security tests |
| `uv run mypy src/tourism_backend` | Success |
| `uv run pip-audit` | No known vulnerabilities found (local package skipped) |
| `uv run pytest tests/security` | 11 passed (with local PostGIS/Redis) |
| `flutter test test/security/` | 2 passed |

## Findings summary

| ID | Severity | Confidence | Status |
| --- | --- | --- | --- |
| SEC-001 | Medium | Confirmed (gap) | Accepted until Phase 6 — auth stub only |
| SEC-002 | Medium | Confirmed | Partial fix — bind 127.0.0.1; Redis AUTH still open |
| SEC-003 | Medium | Confirmed | Partial fix — localhost bind; known local passwords remain DX |
| SEC-004 | Low | Confirmed | Fixed — refuse placeholders in staging/production |
| SEC-005 | Informational | Confirmed | Accepted — no CORS yet; native mobile first |
| SEC-006 | Low | Confirmed | Fixed — generic 500 handler, no client stack traces |
| SEC-007 | Low | Confirmed | Fixed — `q`/`slug` max_length; offset cap |
| SEC-008 | Informational | Confirmed | Accepted — `flutter_secure_storage` unused until Phase 5–6 |
| SEC-009 | Low | Confirmed | Accepted risk for dev HTTP localhost; prod HTTPS in config |
| SEC-010 | Medium | Confirmed | Partial — pip-audit + Ruff S; GitLab SAST/Secret/Trivy pending tier |
| SEC-011 | Medium | Confirmed | Open — single DB role (REQUIRES REVIEW for prod roles) |
| SEC-012 | Low | Confirmed | Open — MinIO root for local bootstrap |
| SEC-013 | Informational | Confirmed | Positive — published-only places filter |
| SEC-014 | Informational | Confirmed | Positive — ORM bound params for search |
| SEC-015 | Informational | Confirmed | Positive — Dockerfile non-root multi-stage |
| SEC-016 | Informational | Confirmed | Positive — explicit response DTOs |
| SEC-017 | Medium | Confirmed | Open — no rate limiting (Phase 6) |
| SEC-018 | Low | Confirmed | Partial — foundation security tests added |

## Finding details (actionable)

### SEC-001 — Authentication not implemented

- CWE-306 / API2
- Evidence: `modules/identity/__init__.py`, `modules/users/__init__.py` stubs
- Attack path: N/A for private data (no private APIs); future risk when added
- Remediation: Phase 6 per ADR-007
- Status: accepted planned gap

### SEC-002 / SEC-003 — Local data plane exposure

- CWE-799 / misconfiguration
- Evidence: Compose published ports + known `.env.example` passwords
- Attack path: LAN attacker connects to Redis/Postgres/MinIO with DX creds
- Remediation applied: `127.0.0.1:` port binds
- Remaining: Redis AUTH, separate credentials — REQUIRES REVIEW for DX impact

### SEC-004 — Placeholder credentials in Settings defaults

- Fixed via `validate_settings()` refusing markers outside development/test/ci

### SEC-006 / SEC-007 — Error leakage / unbounded search input

- Fixed: unhandled exception handler; Query `max_length` / offset bounds

### SEC-010 — Missing security scanners

- Added: Ruff `S`, `pip-audit` in validate + CI job
- Pending confirmation of GitLab tier for Secret Detection / SAST
- Trivy job commented as optional OSS

### SEC-011 / SEC-017 — DB role separation / rate limits

- Documented; implementation REQUIRES REVIEW / Phase 6

## Fixed in this pass

- Security documentation set + ADR-007
- Cursor rule, skill, command
- Localhost Compose binds
- Production placeholder credential guard
- Input length limits on public list endpoints
- Safe unhandled exception response
- Security regression tests (backend + mobile config)
- pip-audit + Ruff security rules + CI notes

## Requires review (not applied)

- Redis AUTH / ACL on local Compose
- Separate Postgres migration vs app roles
- Enabling paid GitLab security templates without tier check
- Certificate pinning
- Full auth/token implementation details beyond ADR

## False positives

- None recorded. `flutter_lldb_helper` / ephemeral Python (prior DX) not a product vuln.

## Not tested

- Live auth flows (absent)
- BOLA on private resources (absent)
- CSRF cookie surfaces (absent)
- File upload / SSRF / AI tools (absent)
- Kubernetes/Helm (absent)
- Staging/production DAST
- Secret detection on full git history
- Container Trivy scan (job not enabled)

## Remaining risks

1. Auth and object-level authZ still future work.
2. Local DX credentials remain well-known (mitigated by localhost bind).
3. No rate limiting yet.
4. Single DB super-capable local role.
5. Dependency/SAST coverage incomplete without GitLab tier confirmation.

## Recommendations

1. Implement Phase 6 strictly against ADR-007 + auth security tests.
2. Before staging: Redis AUTH, DB role split, secret manager, TLS.
3. Confirm GitLab tier; enable Secret Detection / SAST or keep OSS equivalents.
4. Keep using Skill `travel-platform-security-audit` on security-sensitive MRs.

## Disclaimer

This audit covers listed areas and commands only. It does **not** assert that
the project is fully secure or that all vulnerabilities are eliminated.
