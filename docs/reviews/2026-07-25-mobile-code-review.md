# Mobile code review

Date: 2026-07-25  
Repository: `tourism-mobile`  
Reviewed revision: `2a8dcb4` (`gamma`)  
Review mode: read-only; no production code was changed during the review

## Remediation status

Implemented on mobile branch `gamma` after this report was completed:

- `e0eafe3` — validated build flavor/API URL, release network policy and removal
  of Android debug-signing fallback;
- `31b9c93` — in-session favorites state, mandatory swipe callback, functional
  route filters/search and auto-disposed detail providers;
- `704e127` — typed API failure mapping and safe retry UI;
- `3f8a2a5` — compositor-safe filtered alpha around glass cards.

Durable favorites still depend on the Phase 7 authenticated backend API.
Organization-owned Android release signing, Android build verification, and
physical-device Impeller profiling remain external follow-ups.

## Executive summary

The Flutter application has a coherent feature-first skeleton, a shared
`StatefulShellRoute`, centralized design primitives, bundled fonts and images,
strict analyzer settings, secure-storage abstraction, reduced-motion handling,
and useful widget/golden coverage. The full local validation and an iOS
Simulator build pass.

The review nevertheless found four release or core-workflow blockers. Runtime
configuration always selects the development flavor, Android release has no
network permission, Android release is signed with the debug key, and the
swipe-right “favorite” action does not persist or notify any application state.

No embedded secret was found in the tracked repository history inspected by the
review.

## Findings

### P1 - Every app build selects development configuration and mock data

**Evidence**

- `lib/core/config/app_config.dart:52` always creates
  `AppConfig.fromFlavor(AppFlavor.dev)`.
- `lib/main.dart:8` does not override the provider based on a flavor entry point
  or compile-time environment.
- `lib/core/config/app_config.dart:32` points dev to
  `http://localhost:8000`, and dev enables mock data by default.
- `test/security/config_security_test.dart:5` tests `fromFlavor` in isolation
  but never tests the actual `appConfigProvider`.
- The architecture and security documentation prohibit localhost endpoints and
  mock/debug behavior in production builds.

**Impact**

An App Store or Play release built from the current entry point starts as
`КрымТрип (Dev)` with local mock repositories. If mock data is disabled through
`USE_MOCK_DATA=false`, it tries to call the device's own localhost over
cleartext HTTP.

**Required remediation**

Select flavor and API URL from validated compile-time defines or explicit flavor
entry points. Default release builds to production, reject invalid or placeholder
production URLs, and test the actual provider configuration for debug/profile/
release policies.

### P1 - Android release cannot access the network

**Evidence**

- `android/app/src/main/AndroidManifest.xml` has no
  `android.permission.INTERNET`.
- The permission exists only in
  `android/app/src/debug/AndroidManifest.xml:6` and
  `android/app/src/profile/AndroidManifest.xml:6`.
- API repositories and remote media require network access in non-mock builds.

**Impact**

A release APK cannot call the backend or load remote media, even after flavor
selection is fixed.

**Required remediation**

Declare `INTERNET` in the main manifest and add a release-manifest regression
check. Keep cleartext disabled for release.

### P1 - Android release uses the debug signing key

**Evidence**

- `android/app/build.gradle.kts:28` configures the release build.
- `android/app/build.gradle.kts:32` assigns
  `signingConfigs.getByName("debug")`.

**Impact**

Debug signing is not an acceptable release trust root and contradicts the
documented release-security baseline. A build distributed with this identity
cannot safely transition to protected production signing.

**Required remediation**

Load release signing material from CI/local secret configuration that is
excluded from Git. Fail release packaging when signing material is absent;
never fall back to debug signing.

### P1 - Swipe-right “favorite” action is functionally a no-op

**Evidence**

- `lib/features/routes/presentation/widgets/route_swipe_deck.dart:299` invokes
  nullable `widget.onSwipe`.
- `lib/features/routes/presentation/routes_catalog_screen.dart:62` constructs
  `RouteSwipeDeck` without `onSwipe`.
- `route_swipe_deck.dart:297` removes the active route; only a left-skip action
  is appended back to the local deck.
- The UI and onboarding explicitly state that a right swipe adds the route to
  “Избранное”.

**Impact**

The user receives success haptics and a “В избранное” state, but no favorite is
stored. The route simply disappears until the deck or screen is recreated.

**Required remediation**

Make the callback required or connect the deck to a favorites application
controller/repository with optimistic update and rollback. Add a behavior test
that observes favorite state after a committed right swipe.

### P2 - Search, filter button, and chips on the swipe catalog do not filter

**Evidence**

- `lib/features/routes/presentation/routes_catalog_screen.dart:45` supplies
  empty callbacks to search and filter.
- `routes_catalog_screen.dart:50` updates `_selectedChip`.
- `routes_catalog_screen.dart:63` always sends the unchanged `page.items` list
  to the deck.

**Impact**

Controls provide pressed and selected feedback without changing data or opening
a workflow. This is misleading and breaks a primary catalog interaction.

**Required remediation**

Define route filter state in the application layer, pass supported filters to
the repository, and rebuild the deck from filtered results. Disable or remove
controls until their behavior exists.

### P2 - Raw network and parsing exceptions are rendered to users

**Evidence**

- `lib/core/errors/app_failure.dart` defines typed safe failures but is unused.
- `api_places_repository.dart` and `api_routes_repository.dart` let
  `DioException`, null-data errors, and JSON cast errors escape unchanged.
- Home, route catalog/detail, and place catalog/detail render
  `Text('Ошибка: $error')`.

**Impact**

Technical URLs, transport messages, response details, and parser internals can
reach the UI. Error handling is inconsistent and users have no retry action.

**Required remediation**

Map Dio status/timeout/connectivity and decoding failures to typed,
non-sensitive `AppFailure` values in the data layer. Render stable localized
messages with retry controls and test malformed payloads and network failures.

### P2 - Production media resolution accepts cleartext and arbitrary hosts

**Evidence**

- `lib/core/theme/app_images.dart:44` accepts any `http` or `https` absolute
  URL from server data.
- The decision does not consider `AppConfig.flavor` or an allowed media origin.
- The security baseline requires HTTPS for staging and production.

**Impact**

Backend content can request cleartext media or direct clients to arbitrary
third-party hosts, leaking IP/device metadata and producing platform-dependent
failures under ATS/Android cleartext policy.

**Required remediation**

Require HTTPS outside dev and constrain hosts to the API origin or an explicit
compile-time allowlist. Keep the bundled fallback for rejected URLs and add
security tests for HTTP and untrusted hosts.

### P2 - Route-card opacity wraps backdrop-filter subtrees

**Evidence**

- `route_swipe_deck.dart:566` wraps a complete back `RouteHeroCard` in
  `Opacity`.
- `route_hero_card.dart:287` wraps `AppGlassCircle` in `Opacity`.
- `AppGlassSurface` uses `BackdropFilter` at
  `lib/core/design/components/app_glass.dart:63`.

**Impact**

This composition forces extra offscreen layers and is incompatible with
inherited-opacity paths used by Impeller for some backdrop-filter contents.
Widget/golden tests do not run the production GPU renderer, so runtime warnings,
frame drops, or visual corruption can escape the test suite.

**Required remediation**

Avoid parent `Opacity` around glass subtrees. Animate semantic color alpha,
overlay tint, or a compositor-safe transition while isolating repaint regions.
Profile the deck on an iOS simulator/device with Impeller and record frame
timings.

### P2 - Detail providers retain every visited entity for the app lifetime

**Evidence**

- `routes/application/routes_providers.dart:22` uses
  `FutureProvider.family` without `autoDispose`.
- `places/application/places_providers.dart:22` does the same.

**Impact**

Every unique route/place detail remains cached for the lifetime of the provider
container. Long browsing sessions can retain response models and related error
state indefinitely.

**Required remediation**

Use `FutureProvider.autoDispose.family`, optionally with an explicit short
keep-alive policy for back navigation, and add provider lifecycle tests.

### P3 - Core UI files exceed maintainable ownership boundaries

**Evidence**

- `route_details_screen.dart` is 1,265 lines.
- `route_swipe_deck.dart` is 1,110 lines.
- `app_shell_screen.dart` is 662 lines.
- A static scan found 151 direct color/spacing/radius literals under feature
  presentation code despite the documented token system.

**Impact**

Motion, navigation, data presentation, and reusable controls are difficult to
review independently. Large visual changes have a high regression surface and
encourage token drift.

**Required remediation**

Split by owned behavior, not arbitrary line count: detail sections, deck
geometry/motion, coach card, shell CTA, and nav painter. Promote repeated
semantic values to design tokens while preserving golden behavior.

### P3 - Pixel goldens do not protect Linux CI

**Evidence**

- `test/golden/ui_golden_test.dart:78` skips pixel comparisons on non-macOS
  hosts.
- GitLab uses a Linux Flutter image.
- The limitation is correctly documented in `flutter-testing-guide.md`.

**Impact**

CI can pass with a pixel regression; protection currently depends on a local
macOS run before push.

**Required remediation**

Keep the current documented local gate for now, then record deterministic
baselines in a pinned CI renderer or add a required macOS job before release.

## Positive controls observed

- `flutter analyze` enables strict casts, inference, raw types, async and
  lifecycle lints.
- No direct database access, WebView, arbitrary process execution, embedded
  credentials, or plaintext token storage was found.
- Secure storage is behind a port and uses Keychain/Keystore-backed storage.
- Main tab state uses one `StatefulShellRoute` and one shared shell.
- Media schemes such as `file:`, `data:`, and `javascript:` are rejected.
- Rubik and comparison images are bundled; goldens do not use network images.
- Reduced motion and minimum navigation touch targets have explicit tests.
- Golden coverage includes welcome, home, deck states, onboarding, route detail,
  and navigation states.

## Verification performed

| Command/check | Result |
| --- | --- |
| `./scripts/validate.sh` | Passed |
| `dart format --set-exit-if-changed lib test` | 55 files checked, 0 changed |
| `flutter analyze --fatal-infos` | Passed, no issues |
| `flutter test` | Passed, 44 tests |
| Pixel goldens on macOS | Passed as part of the local test run |
| `flutter build ios --simulator --no-pub` | Passed; produced `Runner.app` |
| `flutter pub outdated --no-dev-dependencies` | 2 direct updates available; 9 constraints behind resolvable major versions; transitive `js` package discontinued |
| Tracked secret/signing-material scan | No key, keystore, provisioning profile, or obvious embedded secret found |
| Android build | Not run: Android SDK is unavailable |

## Review limitations

- Android release packaging and merged-manifest output could not be executed
  because `flutter doctor` reports no Android SDK.
- iOS device archive/signing was not tested; only an unsigned Simulator build
  was produced.
- Auth, token refresh, favorites persistence, route execution, payments, and
  offline data are future or placeholder features, so only their current
  foundations were reviewed.
- No physical-device GPU profile or network interception test was run.
