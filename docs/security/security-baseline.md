# Security baseline — КрымТрип

Целевой уровень: прагматичный **OWASP ASVS Level 2** для backend/API;
**OWASP MASVS** baseline для mobile (auth, storage, network, privacy,
platform). Административные и security-critical операции — усиленные
требования.

Соответствие стандарту **не заявляется** без проверки каждого control.
Этот документ — целевой baseline и карта security docs, не сертификат.

## Canonical location

Все security docs живут только здесь:

`tourism-platform/docs/security/`

Не дублировать в backend/mobile/workspace (только ссылки).

## Scope текущего baseline

| Область | Статус |
| --- | --- |
| Security documentation | documented (этот каталог) |
| Threat model | documented (нуждается в refresh под Phase 6–7) |
| Auth/session implementation | **partial** — phone OTP + JWT access + opaque refresh (ADR-007 mobile path) |
| Object-level authZ for private data | **partial** — `/me`, favorites, support; public profile без phone |
| Public content publication filter | implemented for places + public routes (editorial + user_created) |
| Media attachments | implemented (`media_attachments` + profile upload re-encode) |
| Secrets in Git | policy + `.env` gitignore |
| Dependency / SAST CI | foundation jobs documented + open-source gates |
| Container hardening | Dockerfile non-root (backend) |
| Redis/Postgres/MinIO ACL for prod | **not done** (local Compose only) |
| AI/RAG security | documented for Phase 8B+ |

Живое as-built описание: **[security-as-built.md](security-as-built.md)**.

## Documents

| Document | Purpose |
| --- | --- |
| [security-as-built.md](security-as-built.md) | **Как устроено сейчас** (auth, API, mobile, injections) |
| [threat-model.md](threat-model.md) | STRIDE, assets, trust boundaries |
| [data-classification-and-retention.md](data-classification-and-retention.md) | PUBLIC…RESTRICTED, retention |
| [authentication-and-token-security.md](authentication-and-token-security.md) | Passwords, tokens, sessions |
| [backend-api-security.md](backend-api-security.md) | API Top 10, validation, CORS, CSRF |
| [mobile-security.md](mobile-security.md) | MASVS-oriented mobile controls |
| [database-cache-storage-security.md](database-cache-storage-security.md) | Postgres/Redis |
| [file-and-media-security.md](file-and-media-security.md) | MinIO / uploads |
| [secrets-management.md](secrets-management.md) | Secrets, rotation, CI variables |
| [secure-development-lifecycle.md](secure-development-lifecycle.md) | SDLC, exceptions |
| [security-testing-guide.md](security-testing-guide.md) | Tests and scanners |
| [security-incident-response.md](security-incident-response.md) | Incident playbooks |
| [security-checklist.md](security-checklist.md) | Release / MR checklist |
| [../decisions/ADR-007-authentication-and-session-strategy.md](../decisions/ADR-007-authentication-and-session-strategy.md) | Auth strategy decision |

## Non-negotiable invariants

1. External input is untrusted.
2. Authentication ≠ authorization; object-level checks required for private data.
3. Parameterized SQL only; no string-built queries from user input.
4. No secrets in Git, images, logs, or mobile bundles.
5. No plaintext / reversible / weak password hashes (Argon2id when auth lands).
6. No tokens/passwords in logs, analytics, crash reports.
7. Mobile credentials only via Keychain/Keystore-backed storage.
8. Explicit request/response DTOs; no ORM dump to API.
9. No arbitrary HTML / unsafe WebView / arbitrary URL fetch.
10. Limits and timeouts on lists, uploads, external calls, AI tools.
11. Security-sensitive changes need regression tests.
12. Never silently weaken a documented control.

## Related

- [SECURITY.md](../../SECURITY.md) — vulnerability reporting
- Cursor rule: workspace `.cursor/rules/security-baseline.mdc`
- Skill: `.cursor/skills/travel-platform-security-audit/`
- Command: `.cursor/commands/security-audit.md`
