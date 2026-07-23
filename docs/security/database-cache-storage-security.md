# Database, cache, and storage security

## PostgreSQL / PostGIS

### Roles (target)

| Role | Privileges | Usage |
| --- | --- | --- |
| Migration | DDL | CI/migration job only |
| Application | DML on needed schemas | runtime API |
| Analytics read-only | SELECT on views/tables | reporting |
| Backup | minimal backup rights | backups |

Current local Compose uses a single `tourism` user for convenience — **not**
a production pattern (finding SEC-011).

### Hardening checklist

- No PUBLIC grants beyond need; careful `search_path`.
- Review SECURITY DEFINER functions and extensions.
- Network: DB not on public internet; TLS for non-local.
- `statement_timeout`, idle transaction timeout.
- App role: no superuser, CREATEDB, CREATEROLE, BYPASSRLS.
- RLS: optional defense-in-depth for user-owned rows after design review;
  never a substitute for application authorization.

### Sensitive fields

Passwords: hash only (Argon2id). Column encryption only with threat model and
separate keys — not “checkbox encryption”.

### Backups

Encrypted at rest, restricted access, retention documented, restore tested,
separate credentials. No casual production dumps on laptops.

## Redis

Redis is **not** a durable secret store.

Do not cache: plaintext passwords, refresh tokens, reset tokens, full
Authorization headers, private keys, raw confidential prompts, exact location
history without need.

Rules:

- Not exposed publicly in production; AUTH/ACL; TLS across untrusted networks.
- Namespaced keys; TTL; user/tenant in key; invalidate on permission change.
- Do not pickle untrusted objects; no `KEYS` on hot path.
- Separate logical (or physical) DB/instance for security-sensitive session
  metadata vs general cache when justified.

**Current local:** Redis without password, port published for DX
(threat T-09 / SEC-002). Production must not copy this.

## MinIO / object storage

See [file-and-media-security.md](file-and-media-security.md). Local Compose
sets bucket anonymous policy to `none` via `minio-init` — good default.
Root user is used for local bootstrap only.
