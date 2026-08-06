# Secure development lifecycle

## Principles

Security is a **cross-cutting concern**, not deferred to Phase 6 alone.
See [implementation-plan.md](../implementation-plan.md) Security Baseline and
per-phase security rows.

## Workflow

1. Read relevant `docs/security/*` before auth, storage, upload, AI, or infra
   changes.
2. Run Skill `travel-platform-security-audit` for security-sensitive MRs.
3. Prefer SAFE AUTOMATIC fixes; REQUIRES REVIEW needs explicit approval.
4. Add regression tests for security-sensitive behavior.
5. Do not silence scanners with broad noqa without documented exception.

## CI gates (as-built)

| Gate | Blocks |
| --- | --- |
| Gitleaks (backend / mobile / platform) | merge via failed pipeline |
| Semgrep ERROR (backend / mobile) | merge; publish/APK `needs` |
| pip-audit / OSV-Scanner | merge; publish/APK `needs` |
| `pytest tests/security` (dedicated job) | backend publish |
| Trivy HIGH/CRITICAL on image | backend deploy (after publish) |
| Flutter `test/security/` (in `flutter test`) | mobile APK job |

Details: [security-testing-guide.md](security-testing-guide.md).

## Security exceptions

No open-ended “fix later / safe enough / internal only”.

| Field | Required |
| --- | --- |
| ID | `SEC-EX-YYYY-NNN` |
| Finding | link / ID |
| Business reason | concrete |
| Compensating controls | list |
| Risk owner | named role/person |
| Expiration | date |
| Review date | date |
| Remediation plan | steps |

Store exceptions under `docs/security/exceptions/` when first needed
(create file per exception). Expired exceptions block merge of dependent
work until renewed or fixed.

## Severity handling

| Severity | Merge policy |
| --- | --- |
| Critical confirmed | block |
| High confirmed | block or documented temporary exception |
| Medium | triage within sprint |
| Low / Info | backlog |

Scanner outage ≠ clean scan. Missing result ≠ no vulnerabilities.

## Roles

| Role | Responsibility |
| --- | --- |
| Author | secure defaults, tests |
| Reviewer | authZ, secrets, SQL, logging |
| Maintainer | CI gates, exceptions |
| Incident lead | [security-incident-response.md](security-incident-response.md) |
