# Secrets management

## Rules

1. No secrets in Git, Dockerfiles, image layers, or build args.
2. `.env` local only and gitignored; `.env.example` placeholders only.
3. Never print env in CI; avoid `CI_DEBUG_TRACE` with production secrets.
4. Documented rotation; immediate revoke/replace on leak.
5. Prefer external secrets manager before production (GitLab masked vars →
   later Vault/cloud SM).

## Allowed in repository

| Item | Example |
| --- | --- |
| Local placeholder passwords | `local-tourism-password` in `.env.example` |
| Public docs describing secret *types* | “DATABASE_URL”, “GEMINI_API_KEY” |
| Non-secret config | ports, image tags |

## Forbidden in repository

Production DB passwords, API keys, signing keys, refresh tokens, private keys,
real `.env` files, CI_DEBUG dumps.

## GitLab CI variables (target)

- Masked; protected; environment-scoped.
- Hidden when the tier supports it.
- Separate staging vs production.
- Runners: least privilege; no shared unprotected runners for prod deploy.

## Application settings

- Backend `Settings` must refuse known local placeholder credentials when
  `environment` is `staging` or `production`.
- Signing keys for JWT (Phase 6) live outside the app image; support `kid`
  rotation for asymmetric keys; never load keys from untrusted JWKS URLs in
  token headers.

## Mobile

No server/API secrets in APK/IPA. Public SDK keys restricted by package name,
signing cert, API allowlist, quotas.

Firebase client config (`google-services.json`, `firebase_options.dart`,
optional iOS plist) is committed on purpose: those API keys are public
mobile-SDK credentials. Gitleaks allowlists them via
`tourism-mobile/.gitleaks.toml`. Do **not** allowlist server keys or
keystore material.

### Android CI signing (tourism-mobile)

GitLab CI variables for `mobile-apk-test` (masked; prefer protected on
`main`/`gamma`):

- `ANDROID_KEYSTORE_BASE64` — base64 of the upload `.jks` (never commit)
- `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`
- `MOBILE_TEST_API_BASE_URL` — HTTPS test API only (not a secret, but
  environment-scoped)

Job writes ephemeral `android/key.properties` + keystore, then deletes them
before uploading the APK artifact. Keystore must **not** appear in artifacts.

## Rotation triggers

Leak suspicion, staff offboarding, provider incident, scheduled cadence for
high-value keys (signing, DB, object storage, AI/routing).
