# Security incident response

For each incident class: Contain → Revoke → Rotate → Determine exposure →
Preserve evidence → Patch → Notify → Invalidate sessions if needed → Audit
logs → Post-incident review → Add regression control.

Do not put real secrets in tickets or this repo. Mask to type + location +
first/last 2–4 chars if needed.

## Playbooks

### GitLab variable leak

1. Disable/revoke variable; rotate value.
2. Check CI job logs and artifacts for exposure window.
3. Rotate downstream systems that used the value.
4. Review who had Maintainer access.

### Database password leak

1. Rotate DB password; update secret store; recycle app connections.
2. Review connection logs for unexpected sources.
3. Assess dump risk; restore from clean backup if needed.

### Gemini / routing API key leak

1. Revoke key at provider; issue new key.
2. Check provider usage/billing for abuse.
3. Tighten quotas; ensure key not in mobile/Git.

### Signing key leak (JWT or mobile release)

1. Revoke/rotate signing material; invalidate sessions if JWT signing key.
2. For mobile signing: stop releases; rotate keystore/certs per store process;
   treat installed builds as potentially untrusted.

### Refresh token corpus leak

1. Global revoke of refresh families / sessions.
2. Force re-login; notify users if account risk is material.
3. Investigate storage/log path that leaked tokens.

### `.env` published to Git

1. Rotate **all** values that ever appeared in the file (history counts).
2. Purge from Git history only with coordinated force-push policy — rotating
   is mandatory even if rewritten.
3. Add secret scan gate if missing.

### Compromised admin account

1. Disable account; revoke sessions; rotate admin credentials/MFA.
2. Audit admin actions in window; revert malicious changes.
3. Review privilege model.

### Malicious dependency

1. Pin/remove package; rebuild images; rotate any secrets accessible to build.
2. Audit lockfile diff and publish time.
3. Add advisory to pip-audit/pub ignore only with exception record.

### Private location data disclosure

1. Stop the export path; delete exposed artifacts.
2. Assess whose data and retention obligations.
3. Notify responsible persons / users per policy.
4. Patch logging/API; add regression test.

## Evidence

Preserve timestamps, job IDs, commit SHAs, relevant log excerpts (redacted).
Do not destroy logs during triage.

## Contacts

Official security contact is defined outside the public repo until assigned;
see [SECURITY.md](../../SECURITY.md).
