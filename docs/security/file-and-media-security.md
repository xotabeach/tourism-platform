# File and media security

Applies to avatars, place photos, route media (media module — future).

## Upload rules

- Extension + MIME allowlists; **do not trust** `Content-Type`.
- Verify magic bytes; decode with safe libraries; re-encode images when needed.
- Server-generated object keys; never use client filename as key.
- Limit filename length, file size, width/height/pixels; guard decompression bombs.
- Ban executables; SVG banned or strictly sanitized.
- Strip dangerous EXIF (including GPS) unless product explicitly needs it.
- Private buckets by default; no public write.
- Short-lived presigned URLs; object ownership checks.
- `Content-Disposition` and `X-Content-Type-Options` on delivery.
- Malware scan / quarantine — future defense-in-depth for UGC.

Never trust a media URL supplied by the client for server-side fetch without
SSRF controls (see backend-api-security).

## SSRF when fetching remote media

- Prefer server-owned provider URLs.
- Scheme allowlist: `https`.
- Block loopback, private, link-local, metadata endpoints.
- Resolve DNS then connect with rebinding protections; limit redirects;
  size + content-type + timeouts.
- Do not forward user `Authorization` to third parties.

## MinIO

- Separate least-privilege credentials per environment.
- Encryption at rest; lifecycle; backup policy; access audit.
- No secrets in image metadata.
- CORS only for required web origins (future admin).
- Account deletion schedules related object deletes.

## Current state

Compose creates bucket `tourism-media` with anonymous `none`. No upload API
yet — controls above are mandatory when media land.
