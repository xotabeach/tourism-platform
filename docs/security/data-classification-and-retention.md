# Data classification and retention

## Levels

### PUBLIC

Published places, public editorial routes, public place photos, public
category/geography metadata.

### INTERNAL

Operational metrics without PII, non-sensitive analytics aggregates, internal
correlation IDs, build metadata.

### CONFIDENTIAL

Email, profile fields, private routes, favorites, preferences, private trip
data, approximate location (city/region level).

### RESTRICTED

Password hashes; refresh/session/reset/verify tokens; private keys; API
secrets; exact current geolocation; detailed location history; security audit
records; administrative access records; signing keys.

## Rules by class

| Rule | PUBLIC | INTERNAL | CONFIDENTIAL | RESTRICTED |
| --- | --- | --- | --- | --- |
| Storage | DB / CDN / MinIO public read if intentional | DB / metrics | DB encrypted at rest (infra) | DB / secret manager; tokens as digests |
| Logging | OK | OK | minimize; no full profiles | **never** full secrets/tokens/passwords |
| Cache (Redis) | OK with TTL | OK with TTL | short TTL, user-scoped keys | avoid; never plaintext passwords/tokens |
| Encryption in transit | TLS | TLS | TLS | TLS |
| Encryption at rest | preferred | preferred | required (infra) | required; keys separate |
| Default retention | content lifecycle | 30–90 days metrics | account lifetime + grace | tokens: TTL; hashes: until rotate/delete |
| Deletion | editorial workflow | TTL / rollup | account deletion / anonymize | revoke + overwrite digests |
| Backup retention | content policy | short | same as primary + documented | encrypted backups; limited access |
| Staff access | content editors | ops | need-to-know | break-glass + audit |
| User export | public already | N/A | portable subset | never export secrets/hashes |
| Account deletion | keep PUBLIC content authored as editorial | drop user metrics linkage | delete/anonymize | revoke sessions; delete digests |

## Privacy principles

1. **Data minimization** — collect only what a feature needs.
2. **Purpose limitation** — no secondary use without policy update.
3. **Exact geolocation is opt-in** — never continuous GPS history “for later”.
4. Store the **minimum accuracy** needed for the feature.
5. Document retention; delete or anonymize after expiry.
6. Do **not** send private user data to AI providers without explicit need.
7. No PII or tokens in prompts; no training on user data without separate
   consent and policy.
8. Children-related and accessibility preferences are CONFIDENTIAL; do not
   log them casually.

## Location data (Phase 9+)

| Data | Allowed | Not allowed |
| --- | --- | --- |
| Coarse region for catalog filters | yes | — |
| Exact lat/lng of user for active navigation | opt-in, ephemeral or short TTL | permanent free-form tracking |
| Full location history | only with product need + retention | speculative collection |
| Place coordinates (editorial) | PUBLIC content | — |

## AI / RAG data handling

- Candidate place IDs and public editorial facts may enter prompts.
- Private trip notes, email, tokens, exact GPS — default **deny**.
- Retrieved RAG docs are untrusted content (injection).
- Provider retention: prefer zero-retention / enterprise terms when available;
  document actual provider setting before enabling production AI.

## Account deletion (target policy)

1. Revoke all sessions/refresh tokens.
2. Delete or anonymize CONFIDENTIAL profile fields.
3. Delete private routes/favorites/trips or detach ownership per product rules.
4. Schedule MinIO object deletion for user media.
5. Retain minimal RESTRICTED audit evidence for fraud/abuse for a documented
   short window, then purge.
6. Keep PUBLIC editorial content that was never user-private.
