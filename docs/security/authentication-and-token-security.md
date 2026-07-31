# Authentication and token security

Status: **policy + partial as-built (Phase 6)**. Decision:
[ADR-007](../decisions/ADR-007-authentication-and-session-strategy.md).
Living summary: [security-as-built.md](security-as-built.md).

## As-built (mobile path, 2026-07)

- Login: phone OTP (`/auth/otp/request|verify`), not passwords.
- Access: short-lived JWT HS256 (allowlist); claims `sub/iss/aud/exp/iat/jti/typ`.
- Refresh: opaque; SHA-256 digest in Postgres; rotation + family reuse detection.
- Mobile: refresh in Keychain/Keystore; access in memory; Dio single-flight refresh.
- Rate limits (Redis) on OTP request/verify; code compared in constant time.
- OTP verification is always enforced except on a developer machine:
  `AUTH_OTP_ACCEPT_ANY` defaults on only for `APP_ENV=local`, and startup fails
  if it is set in staging/production.
- SMS provider TODO. Until it lands, `AUTH_OTP_STORE_DEBUG_CODE` keeps the code
  readable in `auth_otp_challenges.debug_code` for local/test only — a recorded
  exception to digest-only storage, see
  [SEC-EX-2026-001](exceptions/SEC-EX-2026-001.md).

## Passwords

**Not used in MVP login.** Policy below applies when password auth / admin
lands.

Never store: plaintext, reversible encryption, MD5/SHA-1/SHA-256(password),
passwords in logs/Redis/events/analytics/exception context.

**Algorithm:** Argon2id via a maintained library (e.g. `pwdlib` / `argon2-cffi`),
unique salt from the library, tunable cost, rehash-on-login when parameters
change. No homemade crypto.

**Pepper:** optional defense-in-depth only if stored outside DB, not in Git,
with rotation plan; evaluate ops cost before enabling.

### Password policy

- Reasonable minimum length (prefer ≥ 12); allow long passphrases.
- Do not silently truncate.
- Allow password managers (no paste blocking).
- Avoid pointless composition rules without threat justification.
- Compromised-password check may be added later via safe integration.
- Do not store plaintext password history.

### Enumeration and login abuse

- Same external response for unknown email and wrong password.
- Same password-reset workflow timing/response shape.
- Rate limit per account and per IP (NAT-aware); progressive delay.
- Do not permanently lock accounts solely from attacker traffic.
- CAPTCHA only as risk-based add-on.
- Security logging of success/failure without secrets.

### Step-up / re-authentication

Required for: password change, email change, session management, account
deletion, security settings, admin operations.

## Tokens (native mobile — ADR-007)

### Access token (short-lived JWT)

- Configurable TTL (minutes).
- Minimal claims: `sub`, `iss`, `aud`, `exp`, `iat`, `jti`, `typ=access`.
- No email, exact location, or bulky roles/PII in payload.
- Verify signature, iss, aud, exp, typ; algorithm **allowlist** only
  (no algorithm confusion; never trust `alg` alone).
- Never in URL/query; never logged.
- Prefer in-memory on mobile; refresh after process death.

### Refresh token (opaque)

- Cryptographically random; store **only digest/HMAC** server-side.
- SHA-256 digest of high-entropy token is OK (unlike password hashing).
- Rotate on every refresh; refresh-token family + reuse detection.
- On reuse of an old refresh token: revoke entire family, security event,
  force re-login.
- Absolute and inactivity lifetimes configurable.
- Revoke on logout, password change, account delete, incident, manual device
  revoke.
- Users can list/revoke devices.
- Never return refresh token in logs or error bodies.

### Reset / verification tokens

Random, one-time, short TTL, digest-only storage, invalidate previous tokens,
no PII inside token, invalidate sessions after password reset per policy.

## Mobile storage

- Refresh → `flutter_secure_storage` (Keychain / Keystore-backed).
- Access → memory when possible.
- Logout: clear local credentials, revoke server-side, clear user caches,
  reset Dio auth state.
- Single-flight refresh; no infinite 401 loops.
- No tokens in print/debug/crash/analytics/deep links/clipboard/notifications.

## Authorization reminder

Authn does not grant object access. Private resources always load with
ownership or explicit policy. UUID is not authorization.
