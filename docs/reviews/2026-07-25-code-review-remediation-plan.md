# Code review remediation plan

Date: 2026-07-25  
Source reviews:

- [Backend code review](2026-07-25-backend-code-review.md)
- [Mobile code review](2026-07-25-mobile-code-review.md)

## Goals

1. Close confirmed security and release blockers first.
2. Restore truthful mobile behavior where the UI currently reports actions that
   are not performed.
3. Add regression coverage before or together with each behavior change.
4. Keep backend and mobile commits separate and conventional.
5. Defer broad architecture rewrites until behavior and release gates are
   stable.

## Execution rules

- Backend production edits must be made on `gamma`, never directly on `main`.
- Do not commit secrets, signing keys, generated local configuration, or updated
  goldens without reviewing the diff.
- Do not update package constraints as part of this remediation.
- Each repository must be clean and pass its own quality gate before its
  submodule pointer is updated.
- Missing Docker/Android infrastructure must be reported as a limitation, not
  treated as a pass.

## Phase 1 - Backend security hotfix

Priority: immediate

### Scope

- Return generic readiness failures and log dependency exceptions server-side.
- Bound readiness checks with explicit timeouts.
- Remove raw submitted values from validation error responses.
- Prevent public route list/detail/cover queries from exposing routes that
  reference unpublished places.
- Add deterministic `(name, id)` ordering while the relevant queries are being
  touched.
- Protect lifespan cleanup with `try/finally`.

### Tests

- Unit tests for database and Redis readiness failures proving exception text is
  not returned.
- Unit/API test proving validation input is not reflected.
- Integration security regression for a public route with an unpublished stop.
- Pagination ordering assertion with duplicate names where practical.

### Commit boundary

`fix(backend): harden public route and error handling`

## Phase 2 - Backend query and test-gate hardening

Priority: high

### Scope

- Select PostGIS coordinates in list queries rather than one query per item.
- Make integration dependency absence fail in CI while preserving an explicit
  local skip mode.
- Introduce integration markers and a non-zero, ratcheted coverage threshold
  after the integration suite runs reliably.

### Tests

- Repository/query-count coverage for place, region, and locality lists.
- CI-mode test proving unavailable dependencies fail rather than skip.
- Full migration, seed, integration, and security suite with Postgres/Redis.

### Commit boundary

`perf(backend): remove catalog coordinate n plus one queries`

`test(backend): make integration gates fail closed in ci`

## Phase 3 - Mobile release safety

Priority: immediate

### Scope

- Select `dev`, `staging`, or `production` from a validated compile-time define.
- Default release mode to production and debug/profile mode to dev.
- Support an explicit compile-time API base URL; reject cleartext or placeholder
  values outside dev.
- Put Android `INTERNET` permission in the main manifest.
- Remove debug signing fallback from release.
- Add a documented, ignored release-signing properties flow that fails release
  packaging when credentials are absent.
- Restrict non-dev media to HTTPS and trusted hosts.

### Tests

- Actual provider/runtime policy tests, not only `fromFlavor` unit tests.
- Media URL tests for HTTP, foreign hosts, relative URLs, and dev behavior.
- Static native test for main-manifest permission and absence of debug release
  signing.

### Commit boundary

`fix(mobile): enforce release configuration and network policy`

## Phase 4 - Mobile truthful state and failures

Priority: high

### Scope

- Add an application-level favorites controller for the current local/mock
  phase and connect committed right swipes to it.
- Make the deck swipe callback non-optional so success UI cannot silently do
  nothing.
- Move route filter matching out of presentation and make chips affect the
  visible deck.
- Give search/filter controls real behavior or disable them until their contract
  is available.
- Map Dio and decoding failures to safe typed failures.
- Replace raw exception text with stable messages, retry actions, and semantic
  error states.
- Make route/place detail family providers auto-dispose with a deliberate short
  keep-alive only if navigation UX requires it.

### Tests

- Committed right swipe updates observed favorites state.
- Left swipe does not favorite and keeps cycling behavior.
- Selected filter changes deck contents.
- Dio timeout, 404, malformed payload, and unknown failure mapping.
- Error UI does not render a raw URL, response payload, or submitted secret.
- Provider disposal coverage.

### Commit boundary

`fix(mobile): connect swipe actions and catalog filters`

`fix(mobile): map api failures to safe retry states`

## Phase 5 - Mobile rendering performance

Priority: high

### Scope

- Remove parent opacity layers around backdrop-filter card subtrees.
- Keep deck repaint regions isolated and preserve current golden geometry.
- Profile route drag, coach blur, and shared nav animation with Impeller.
- Record frame timing and remaining warnings on simulator and a physical device
  when available.

### Tests

- Existing swipe and nav goldens remain unchanged unless reviewed.
- Widget assertion ensures back cards do not use a parent `Opacity`.
- Manual simulator/device run has no inherited-opacity Impeller warnings.

### Commit boundary

`perf(mobile): avoid opacity layers around glass cards`

## Phase 6 - Deferred architecture work

Priority: planned, not part of the hotfix

### Backend

- Add repository protocols and move SQLAlchemy/PostGIS code from application
  services into infrastructure adapters.
- Replace route filter strings with shared enums.
- Define keyset pagination before catalogs become high-write surfaces.

### Mobile

- Split route detail, swipe deck, and shell by owned behavior.
- Move remaining semantic color/spacing/radius literals into design tokens.
- Add generated JSON DTOs only if they reduce real parser/test complexity.
- Establish a required deterministic pixel-golden CI renderer.
- Plan dependency major upgrades separately; do not bundle them with fixes.

## Infrastructure and product dependencies

The following items cannot be fully closed in the current local environment:

- Backend integration/security runtime verification needs a working Docker
  daemon with Postgres/PostGIS and Redis.
- Android merged-manifest and release packaging verification needs Android SDK.
- Production Android signing needs organization-owned keystore/CI secrets.
- Durable cross-device favorites need the planned authenticated backend
  favorites API; the immediate mobile fix can only provide truthful in-session
  state.
- Physical-device Impeller profiling needs an available unlocked device.

## Completion checklist

- [x] Backend security hotfix implemented and tested.
- [x] Backend N+1 and CI test-gate fixes implemented.
- [x] Mobile release configuration and platform policy fixed.
- [x] Swipe favorite/filter behavior connected.
- [x] Typed safe network failures and retry UI implemented.
- [ ] Backdrop-filter opacity composition removed and profiled.
  Composition is fixed and goldens are reviewed; physical-device profiling is
  still pending.
- [x] Backend `./scripts/validate.sh` passes with skip count reported.
  Result: 17 passed, 24 skipped, 79.89% coverage.
- [x] Mobile `./scripts/validate.sh` passes. Result: 54 tests.
- [x] iOS Simulator build passes.
- [x] Android limitation or build result recorded. Android SDK is unavailable.
- [x] Review reports and progress updated.
- [x] Backend and mobile remediation branches pushed to `gamma`.
- [ ] Platform report commit and superproject pointers pushed to `gamma`.
