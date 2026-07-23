# Backend API security

Maps to OWASP API Security Top 10 (2023) for the FastAPI modular monolith.

## Current state (2026-07-23)

- Public read APIs: geography, categories, places (published only).
- No CORS middleware (native mobile does not rely on CORS).
- No auth middleware.
- Explicit response DTOs for places/geography.
- Pagination `limit` capped 1–100 on places.
- ORM/parameterized queries for search (`ilike` with bound pattern).

## API Top 10 controls

| # | Risk | Baseline control |
| --- | --- | --- |
| 1 | BOLA | Ownership/`policy` on every object ID; negative tests |
| 2 | Broken auth | ADR-007; Argon2id; refresh rotation; rate limits |
| 3 | Property-level | Separate request/response schemas; `extra=forbid` |
| 4 | Resource consumption | max page/body/array/upload/timeouts/quotas |
| 5 | BFLA | Role checks server-side; admin routes isolated |
| 6 | Sensitive flows | Quotas on reset, generation, AI |
| 7 | SSRF | No arbitrary URL fetch; allowlists |
| 8 | Misconfig | Secure defaults; no debug in prod; CORS allowlist |
| 9 | Inventory | Versioned `/api/v1`; document deprecated paths |
| 10 | Unsafe consumption | Validate external/AI responses with schemas |

## Authorization matrix (target)

| Action | Anonymous | User | Editor | Moderator | Admin | Service |
| --- | --- | --- | --- | --- | --- | --- |
| Read published place/route | yes | yes | yes | yes | yes | yes |
| Read draft editorial | no | no | yes | yes | yes | yes |
| Mutate own favorites | no | yes | yes | yes | yes | — |
| Mutate others' private data | no | no | no | limited | yes* | — |
| Admin identity ops | no | no | no | no | yes | — |
| Generate route | no | yes+quota | yes | yes | yes | — |

\*Admin access audited; prefer impersonation/break-glass patterns later.

## Input validation

All external inputs untrusted: body, query, path, headers, tokens, files,
deep links, Redis/MinIO metadata, AI output, provider responses, user-created
DB content, env vars.

Pydantic must bound: string lengths, numerics, arrays, pagination,
coordinates, enums, dates, stop counts, nested depth.

Forbidden: `pickle` of untrusted data, `yaml.load` without SafeLoader,
`eval`/`exec`, `shell=True` with user params, dynamic import from user input.

## SQL

Use ORM/Core expressions and bound parameters. Dynamic sort/filter via
**server allowlists** only. App DB role: no superuser/CREATEDB/CREATEROLE.

## CORS

CORS is not authorization. Production origins explicit allowlist; never
wildcard + credentials; separate dev origins. Mobile clients can call APIs
directly regardless of CORS.

## CSRF

- **Bearer native mobile:** classic cookie CSRF is not the primary threat;
  do not add CSRF tokens “for show”.
- **Cookie web/admin (future):** synchronizer or signed double-submit,
  Origin/Referer checks, SameSite, no state-changing GET, `__Host-` cookies
  when possible.

## XSS (stored via JSON)

Treat user/AI text as untrusted. Store plain text; encode on render.
Rich text only via safe Markdown subset + sanitizer. WebView rules in
mobile-security.md. Future admin: CSP, auto-escaping templates.

## Errors and logging

Client errors: stable codes, no stack traces, no SQL, no paths, no env.
Correlation ID server-side. Never log Authorization headers or tokens.
Security events: login, refresh reuse, logout, password/email change,
denied authZ, admin actions, quota violations, invalid tokens.

## Required limits (target)

- pagination max / page size max
- request body max
- upload max + image pixels
- external provider timeout + retry cap
- AI token/tool-call/candidate max
- route-generation / password-reset / login quotas
