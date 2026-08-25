# Mobile UI/UX consistency review

Date: 2026-08-25  
Repository: `tourism-mobile`  
Reviewed revision: `2e12d64` (`main`)  
Review mode: read-only; no production code changed during the review  
Scope: visual/UX consistency and design-system discipline only — correctness
bugs are covered separately by
[Backend architecture & AI review](2026-08-25-backend-architecture-ai-review.md)
(backend) and an equivalent `/code-review ultra` pass (mobile, run by the
user). Screens already reviewed in depth earlier the same day (home,
place/route details, swipe deck, chat history) are out of scope here — this
pass targets the rest of the app: settings, profile/achievements,
onboarding/auth, search, my_routes, route_publish.

## Executive summary

Two findings are the same class of bug already found and fixed on the Home
screen earlier the same day (a `.when()` loading branch that replaces the
*entire* screen instead of just its content) — see finding 1. One screen
(`SearchScreen`) looks like dead code with a real navigation trap inside it,
left over from before `InPlaceSearchBody` became the app's in-place search
pattern. The rest are consistency/polish items, not regressions.

## Findings

### 1. `my_routes_screen.dart:117` — whole-screen loading flash (P1, same bug class as the Home fix)

`ColoredBox(child: routesAsync.when(...))` is the entire screen body — title
("Моё избранное:"), search bar, and the favorites/history/places/subscriptions
tab switcher are all built *inside* the `data:` branch (confirmed at lines
130–165), not outside it. On first load the whole tab flashes to one centered
spinner, exactly like the Home → Локации bug fixed earlier today. Needs the
same treatment: extract the header out of the `.when()`, use
`AppSkeleton`/`AppShimmer` (`core/design/components/app_skeleton.dart`) for
the loading state.

### 2. `my_routes_screen.dart:118,271,342` — raw exception text on error (P1)

Three separate sites do `Text('Не удалось загрузить ...: $error')` — the raw
Dart exception `toString()` interpolated directly into user-facing text, no
retry action, not using `AppAsyncErrorView`
(`core/design/components/app_async_error.dart`), which is already the
established pattern elsewhere (`routes_catalog_screen.dart`,
`places_catalog_screen.dart`).

### 3. `SearchScreen` (`/search`) — apparently dead code with a latent trap (P2)

`search_screen.dart` has no back button, no swipe-back, and
`InPlaceSearchBody` (what it wraps) has no close/back affordance either. A
grep for `AppRouteNames.search` as a navigation target across the app found
**no call sites** — every other screen (Home, Routes, Places, MyRoutes) uses
`InPlaceSearchBody` in place instead of navigating to this standalone screen.
Recommendation: confirm it's unreachable and delete it, rather than fix its
back button — fixing a dead screen just hides that it's dead.

### 4. `AuthIdentityScreen` / `AuthOtpScreen` — no back affordance during auth (needs product confirmation)

Neither screen has a back button, swipe gesture, or `AppBar` (192 and 476
lines respectively, zero `onBack`/`IconButton`/`context.pop` hits). May be
intentional (don't let users abandon auth mid-flow), may be an oversight that
strands a user who changed their mind. Confirm before touching.

### 5. `route_details_screen.dart` — never migrated to design tokens (P2, tech debt)

20 hardcoded `BorderRadius.circular(N)` + 17 hardcoded hex colors. Notable
because this is the screen `place_details_screen.dart` was deliberately made
to visually mirror earlier the same day — it's the de-facto reference screen
for this pattern family, but was never itself migrated to
`AppRadii`/`AppColors`. Any future "make X match the route screen" work
inherits this debt.

### 6. Icon buttons without accessibility labels (P2)

8 files have `IconButton`s with zero `tooltip:`/semantic labeling anywhere in
the file: `settings_support_screens.dart`, `settings_travel_plus_screen.dart`,
`settings_prefs_screens.dart`, `settings_widgets.dart`,
`route_match_results_screen.dart`, `route_match_widgets.dart`,
`route_hero_card.dart`, `welcome_screen.dart`. Screen readers get no label for
these controls. Settings is the concentration — a single sweep there covers
most of it.

### 7. Parallel color-token files (needs a quick audit, P3)

Three feature-scoped token files exist alongside the shared
`core/design/app_colors.dart`: `settings_widgets.dart` (29 hex literals,
effectively its own `SettingsColors` palette), `route_builder_design_tokens.dart`
(24), `publish_route_design_tokens.dart` (11). Feature-scoped tokens are a
legitimate pattern by themselves, but there's no visible check that they
don't silently duplicate/drift from `app_colors.dart` under different names —
worth a one-time diff.

### 8. Bare spinners instead of skeletons — contained, not full-screen (P3, cosmetic)

`routes_catalog_screen.dart:210`, `places_catalog_screen.dart:263`,
`all_list_screen.dart:168,193`, `settings_notifications_inbox_screen.dart:42`,
`achievements_screen.dart:56`, `settings_support_screens.dart:587` all use a
bare `CircularProgressIndicator()` rather than `AppSkeleton`/`AppShimmer`.
Lower severity than finding 1 because the header sits outside the loading
branch in each of these — only the content region blanks, not the whole
screen. `profile_screen.dart`'s `_ProfileLoadingView` is the positive
reference pattern to standardize on.

### 9. Duplicated empty-state strings (P3, cosmetic)

`'Маршруты не найдены'` / `'Локации не найдены'` / `'Места не найдены'` — three
near-duplicate strings for the same concept, no shared icon+message+action
component. The swipe deck's `_DeckExhaustedView` (added earlier the same day)
is a better model to standardize on.

### 10. Animation/transition consistency — not fully verified

Spot-checked `AppMotion.*` usage across sampled screens; no glaring outliers
found, but this was not exhaustively audited. Treat as unverified, not clean.

## Priority order

1. `my_routes_screen.dart` loading + error states (findings 1–2) — exact same
   bug class already flagged and fixed once on Home.
2. Resolve `SearchScreen` (finding 3) — delete if confirmed dead.
3. Confirm auth-flow back-navigation is intentional (finding 4).
4. Settings `IconButton` tooltip sweep (finding 6) — cheap, real
   accessibility win.
5. Token-migrate `route_details_screen.dart` (finding 5) given it's the
   pattern other screens copy from.
