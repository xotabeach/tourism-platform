# Security checklist

Use for MRs and releases. Check only what was actually verified.

## Every MR

- [ ] No secrets added (`.env`, keys, tokens).
- [ ] New endpoints have authn/authZ story (or explicitly public).
- [ ] Private object access uses ownership/policy (not UUID alone).
- [ ] Request schemas whitelist fields; no mass assignment of roles/owner.
- [ ] SQL uses bound parameters / ORM; sorts via allowlist.
- [ ] Inputs bounded (length, pagination, uploads).
- [ ] Logs omit secrets/tokens/passwords/precise GPS.
- [ ] Security-sensitive change has regression test.
- [ ] Docs updated if control/policy changed.

## Auth / identity MR (Phase 6+)

- [ ] Argon2id (or approved lib); no weak hashes.
- [ ] Enumeration-safe responses.
- [ ] Rate limiting on login/reset.
- [ ] Refresh rotation + reuse detection.
- [ ] Logout/password change revokes sessions.
- [ ] Mobile secure storage for refresh.

## Release / staging (Phase 10+)

- [ ] Dependency audit clean or exceptions filed.
- [ ] Secret scan clean.
- [ ] Container scan triaged.
- [ ] No local placeholder passwords in staging/prod config.
- [ ] TLS on external endpoints.
- [ ] Backup restore smoke (if DB release).
- [ ] Incident contacts reachable.
- [ ] Security Baseline docs still accurate.

## Explicit non-claims

Passing this checklist does **not** mean “fully secure” or “all
vulnerabilities fixed”. It means listed controls were reviewed for this change.
