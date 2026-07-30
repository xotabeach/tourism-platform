# Mobile security (Flutter)

Baseline: OWASP MASVS categories relevant to CrimeaTrip. As-built summary:
[security-as-built.md](security-as-built.md).

Phase 6 mobile path is live: OTP UI → API tokens; refresh via
`flutter_secure_storage` (Keychain/Keystore); access in memory; Dio Bearer +
single-flight refresh.

## Storage

| Data | Allowed | Forbidden |
| --- | --- | --- |
| Refresh token | Keychain/Keystore via secure storage adapter | SharedPreferences, plain SQLite/Hive without KMS, files, assets, Dart constants |
| Access token | Memory preferred | Durable storage without ADR exception |
| Offline catalog cache | App sandbox, non-secret | Mixing with credentials |
| PII offline | Minimize | Public/external storage |

Logout / account deletion must clear credentials and user-scoped caches.

## Network

- Production/staging: HTTPS only. Bootstrap validates `APP_FLAVOR` and requires
  an explicit, non-placeholder `API_BASE_URL`; release defaults to production.
- Dev may use `http://localhost` — never ship cleartext exceptions to production
  Android Network Security Config / iOS ATS broad exceptions.
- Timeouts already set on Dio (connect 10s, receive 20s).
- Non-dev remote media must use HTTPS and the configured API origin.
- Certificate pinning: **not** enabled by default; requires threat + rotation
  analysis before adoption.
- No secrets in query strings.

## Deep links (Phase 5+)

- Prefer verified App Links / Universal Links.
- Allowlist routes; strict parsing.
- Never accept session tokens from arbitrary deep links.
- Reset links are one-time; defend open redirects.

## WebView

Avoid unless necessary. Disable JS by default; no arbitrary navigation;
no secret injection; no insecure JS bridges; no mixed content; open external
links safely.

## Platform / release

- Document minimum OS versions when releasing.
- Protect signing keys; disable debug menus/features in release. Android release
  packaging must use organization-owned signing configuration and never fall
  back to the debug key.
- No test credentials, localhost endpoints, verbose network logging, or
  stack traces in production builds.
- Avoid secrets on clipboard; lock-screen notifications without sensitive detail.
- Screenshot policy for auth screens: evaluate per threat model.

## Root / jailbreak

May be a risk signal only. Not a security boundary. Do not rely on detection
instead of backend authorization.

## Obfuscation

Resilience only. Embedded secrets are extractable. No server secrets in the
bundle. Public map/SDK keys must be package/signing/API restricted with quotas;
secret operations stay on backend.

## Concurrency-safe refresh (Phase 6)

One in-flight refresh; waiters share result; failed refresh → logged-out state;
no refresh storm / infinite 401 retry.
