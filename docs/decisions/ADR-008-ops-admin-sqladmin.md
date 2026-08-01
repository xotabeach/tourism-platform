# ADR-008 — Ops admin via SQLAdmin

## Status

Accepted (Phase 6.5)

## Context

Phase 6.5 needs an internal ops UI for users, OTP debug codes (local/test),
admin principals, and support replies. The original plan described hand-rolled
HTML/CSS tabs. The backend is already FastAPI + SQLAlchemy async.

## Decision

Use **SQLAdmin** mounted at `/admin`:

- server-rendered HTML (not a separate SPA);
- ModelViews over existing ORM models;
- `AuthenticationBackend` with **cookie sessions** (Starlette
  `SessionMiddleware`), Argon2id-hashed admin principals — **not** mobile JWT;
- mutating `/admin` requests checked for matching `Origin`/`Referer` (CSRF-ish);
- bootstrap principal from `ADMIN_BOOTSTRAP_*` env on local/test.

## Consequences

- Faster delivery than custom Jinja CRUD; dependency on `sqladmin` / WTForms.
- Admin identity tables are separate from mobile `users` (no `is_admin` on User).
- Full CMS for places/routes remains out of scope.
- UI is branded via template/CSS overrides under
  `modules/admin/theme` (CrimeaTrip tokens + Rubik), not a separate SPA.

## Follow-up (2026-08-01)

Shipped on the same ADR boundary (still SQLAdmin, not a SPA):

- **Users:** editable ops fields (display name, phone E.164, travel points,
  notify flags) with `admin.user_update` audit; list/detail show avatar and
  cover from `media_attachments` using allowlisted `/media/` URLs only.
- **OTP:** newest-first default sort; filter by phone and by linked user id
  (phone join — OTP rows have no `user_id` until verify).
- **Support:** ticket details template is a left/right bubble chat with
  operator compose posting through existing `operator_reply`.
