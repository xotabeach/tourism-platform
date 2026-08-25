# 2026-08-25 review remediation plan

Date: 2026-08-25 (updated same day after the mobile code/security/perf pass)  
Source reviews:

- [Backend architecture & AI review](2026-08-25-backend-architecture-ai-review.md)
  (Cursor, read-only, `tourism-backend` @ `4fb9a11`)
- [Mobile UI/UX consistency review](2026-08-25-mobile-ux-review.md)
  (this session, `tourism-mobile` @ `2e12d64`) — visual/UX consistency only.
- [Mobile code, UI implementation, security & performance review](2026-08-25-mobile-code-security-perf-review.md)
  (Cursor, `tourism-mobile` @ `2e12d64`) — deeper pass building on the UX
  review above; two of its top findings (`CODE-1`, `SEC-1`) were independently
  re-verified against the source in this session before being added here.
- Architecture/microservices verdict — a second independent pass this session
  (four questions on ADR-001/002, `route_builder` split, prod-host RAM ceiling)
  reached the same conclusion as the backend review's own architecture
  section: **don't split anything now**; formalize LM Studio as an external
  dependency instead of extracting a service for it. No separate doc — folded
  into "Explicitly not now" below.

Not a full implementation plan — a prioritized backlog to work from. Each
phase is independently shippable; do not block phase N+1 on phase N being
fully done unless noted. Phases are ordered by severity × cost, not by which
review they came from.

## Merge status — 2026-08-26

**Phases 0–6 are merged to `main` in both repositories.** Phases 7–8 are not
started.

| Repo | `main` | Validation |
| --- | --- | --- |
| `tourism-backend` | `ecb1993` | `validate.sh` green — 394 passed, 1 skipped, coverage 74.65% |
| `tourism-mobile` | `0e69467` | `validate.sh` green — 245 tests + 25 goldens, format/analyze clean |

Each phase was merged one at a time with validation in between. Backend was a
fast-forward. Mobile needed real conflict resolution because every branch was
cut from `main` independently, and because an unmerged working session from
2026-08-25 (recovered from a stash into
`feat/home-modes-and-chat-history`, commit `62885c0`) touched the same files:

- **Phase 2** had made `homePlacesProvider` an alias of `placesListProvider`
  because the real limited provider only existed in the unmerged session.
  Resolved to the real provider; refresh scopes target it unchanged.
- **Phase 4**'s narrowed `sessionProvider.select` won over the wider watch;
  the home header now takes `name`/`avatarUrl` as parameters, threaded
  through both mode builders and the loading/error shells.
- **Phase 5**'s `RouteMatchNotifier` is where session resume now lives
  (`resumeSession`), moved out of the screen's `State` where the recovered
  session had put it. Covered by two new notifier tests.
- **Phase 6** branched before the 2026-08-25 hero fixes, so its shared
  extraction had carried the *pre-fix* lip (fading + scaling, detaching
  mid-scroll). Kept `CollapsingSheetLip`; adopted phase 6's shared
  `EntityReviewsSection` and `AudioGuideCard` wholesale.

**Debt this merge surfaced:** `EntityReviewsSection` was extracted from the
pre-token-pass reviews file, so it carries 8 hardcoded colours and 13
hardcoded radii — the 2026-08-25 token pass on `place_reviews_section.dart`
did not survive the unification. Folded into phase 8's token work below.

## Goals

1. Close exploitable P1 bugs first — backend security races/self-activation,
   and the mobile chat-image media-allowlist bypass — before anything else.
2. Fix the loading/cache bug classes that are now confirmed to repeat across
   multiple screens (full-screen loading flash; stale data after an explicit
   pull-to-refresh) rather than patching one instance and leaving siblings.
3. Harden the two things everything else depends on: the LM Studio boundary
   (backend) and the AI-chat screen's total absence of behavioral tests
   (mobile) — both are the product's core differentiator and its least
   tested surface.
4. Batch the rest (design-token cleanup, cross-ORM hygiene, P2/P3 perf) —
   real, but don't let it block 1–3.

## Phase 0 — Backend security/correctness P1s

Priority: immediate. Source: backend review §3 (`M-1`..`M-4`, `AI-3`..`AI-5`).

Branch: `tourism-backend` `fix/backend-security-p1` (HEAD `9b7bd3c`).
`./scripts/validate.sh` 2026-08-25: ruff/mypy/pip-audit clean; pytest
**384 passed**, 1 skipped; coverage 74.38%.

- ~~**M-1** — mock Travel+ self-activation works in any environment
  (`subscriptions/presentation/router.py`) — anyone can grant themselves
  premium. Gate to non-production, or remove from prod routing.~~
  ✅ done 2026-08-25, `e2276cd` — `mock_self_activate_allowed` in entitlements;
  HTTP + service refuse `mock_checkout` outside local/test.
- ~~**M-4** — refresh-token rotation has no row lock (`identity/.../service.py`,
  `refresh_tokens`) — race window on concurrent refresh. Needs `FOR UPDATE`
  on the row read before rotation.~~
  ✅ done 2026-08-25, `f1d6f0d` (+ concurrent HTTP regression in `7fbc4f8`
  test module).
- ~~**M-2** — reusable/cover media list has no publication filter
  (`place_covers.py`, `media/.../list_reusable_covers`) — can surface media
  from unpublished places.~~
  ✅ done 2026-08-25, `4e4dba2`.
- ~~**M-3** — favorited routes don't respect catalog publication rules
  (`favorites/.../service.py`).~~
  ✅ done 2026-08-25, `7fbc4f8` — add/list use the catalog filter including
  `publication_status=published`.
- ~~**AI-5** — route-generation quota is check-then-insert, no lock
  (`quota.py` ~43–74) — mobile retry storms make this likely, not theoretical.~~
  ✅ done 2026-08-25, `196658b` (`9b7bd3c` adapted the quota unit fake session
  to implement `scalar` after the lock).
- ~~**AI-4** — injection/crisis-flagged user text is persisted and re-enters
  the LLM's context on the next turn via history (`session_service.py`
  ~336–348 + history load). Store redacted or omit flagged turns from replay.~~
  ✅ done 2026-08-25, `e0bb6d6` — persist `[redacted]`, omit from LLM history.
- ~~**AI-3** — short affirmatives (`да`/`ок`) force `generate` even
  mid-clarification (`topic_guard.py` ~114–141, `session_service.py` ~314).
  Only treat as generate-confirm when `ask_field` is already
  `ready`/pending.~~
  ✅ done 2026-08-25, `e0bb6d6` (same commit as AI-4: both live in
  `topic_guard.py` / `session_service.py`).

## Phase 1 — Mobile: chat images bypass the media allowlist (security + perf, same root cause)

Priority: immediate. Source: mobile code/security/perf review, `SEC-1` /
`PERF-1` / `SEC-4`. Re-verified in this session: `chat_place_chip.dart:41`,
`chat_route_proposal_card.dart:241,940` are confirmed the only three
`Image.network(...)` call sites in `lib/` — every other image in the app goes
through `AppImages.coverImage`/`resolveMediaUrl`.

Branch: `tourism-mobile` `fix/chat-image-allowlist` (HEAD `52a9507`).
`./scripts/validate.sh` 2026-08-25: dart format + `flutter analyze --fatal-infos`
clean; flutter test **210 passed**; macOS goldens **25 passed**.

- ~~Route all three AI-chat image call sites through `AppImages.coverImage` (or
  `resolveMediaUrl` + a bounded provider) instead of raw `Image.network` on
  an unvalidated URL straight from the AI/API response. This is the one place
  in the whole app where an image URL bypasses the scheme/host allowlist
  (`resolveMediaUrl` in `app_images.dart`) — and simultaneously the one place
  doing full-resolution decode on small slots (148×72 chip, 66px-tall gallery
  row), same defect class already fixed today in `coverImage` itself.
  `test/security/image_cache_security_test.dart` is green today only because
  it unit-tests the allowlist function, not these call sites — add a widget
  regression on the chat chip/proposal card so this can't silently regress
  back.~~
  ✅ done 2026-08-25, `881107f` — `ChatPlaceChip`, gallery thumbs, and
  `CatalogRoutePreviewHeader` use `AppImages.coverImage`; widget test would
  fail on `Image.network` (`javascript:` / off-origin). `52a9507` is dart
  format only so `validate.sh` matches main's previously unformatted files.

## Phase 2 — Mobile: stale data + full-screen loading, now confirmed systemic

Priority: high. Source: mobile UX review (findings 1–2) + mobile code review
(`CODE-1`, `CODE-2`, `UX-7`, `UX-9`). Re-verified `CODE-1` in this session:
`app_data_refresh.dart:116-118` — the `home` scope invalidates
`homeRoutesProvider` and `topTravelersProvider` only; `homePlacesProvider` is
never invalidated by any scope, including `all`.

Branch: `tourism-mobile` `fix/stale-cache-and-loading-flash` (HEAD `ae7891b`).
`./scripts/validate.sh` 2026-08-25: dart format + `flutter analyze --fatal-infos`
clean; flutter test **213 passed**; macOS goldens **25 passed**.
`homePlacesProvider` is an alias of `placesListProvider` on this revision (no
separate limited fetch yet); refresh scopes target the alias the same way they
target `homeRoutesProvider`.

- ~~**`homePlacesProvider` missing from refresh entirely** (`CODE-1`) — pull to
  refresh on Home → Локации, and even `AppDataRefreshScope.all`, leave places
  stale. Add it to the `home` (and `all`) case in `_invalidateScope`.~~
  ✅ done 2026-08-25, `9fa0078` — `home`/`all` invalidate and await
  `homePlacesProvider`; regression in `app_data_refresh_test.dart`.
- ~~**`myRoutes` refresh doesn't invalidate `placesListProvider`** (`CODE-2`)
  even though that screen watches favorited places through it
  (`app_data_refresh.dart:121-123`).~~
  ✅ done 2026-08-25, `9fa0078`.
- ~~**`my_routes_screen.dart`** full-screen loading flash + raw exception text
  at 3 sites (118/271/342) — same fix pattern already applied to Home today.~~
  ✅ done 2026-08-25, `9fa0078` — title/search/tabs stay outside
  `routesAsync.when`; list uses skeleton / `AppAsyncErrorView`.
- ~~**`home_screen.dart:316-319`** error branch (`UX-7`) doesn't preserve the
  header the way the loading branch now does — same class of bug, error path
  instead of loading path.~~
  ✅ done 2026-08-25, `9fa0078` — error keeps greeting header; no raw
  exception text.
- ~~**`achievements_screen.dart`** (`UX-9`) — filter/search UI lives only
  inside the `data:` branch, same antipattern.~~
  ✅ done 2026-08-25, `9fa0078`. `ae7891b` is a test-harness lint fix;
  `7d66163` is dart format only so `validate.sh` matches main.

Worth doing together: the underlying antipattern (`AsyncValue.when` as the
Scaffold body root, with chrome built inside `data:`/absent from `loading:`)
is now confirmed on 3+ screens independently. If touching a 4th instance
later, consider a small shared helper instead of hand-rolling the fix a 4th
time.

## Phase 3 — Backend: LM Studio boundary hardening

Priority: high. Source: backend review §5 + `AI-1`/`AI-2`/`AI-6`..`AI-9`.
Both the backend review and this session's independent architecture pass
converged on the same fix — formalize the boundary, don't extract a service.

Branch: `tourism-backend` `fix/lm-studio-hardening` (HEAD `ecb1993`, stacked
on Phase 0). `./scripts/validate.sh` 2026-08-25: ruff/mypy/pip-audit clean;
pytest **394 passed**, 1 skipped; coverage 74.65%.

- ~~In-process concurrency guard around the LM Studio call (`asyncio.Semaphore`
  or small queue) + a fast "занято, подождите" instead of a 60s hang into
  fallback. One local GPU serves every concurrent chat today with zero
  protection against queueing.~~
  ✅ done 2026-08-25, `c5da3b6` — in-process slot (`acquire_inference_slot`);
  second caller gets `AIProviderBusyError` / «занят… Подождите», not the
  outage fallback.
- ~~Per-turn metrics: `provider`, `latency_ms`, `structured_parse=ok|fallback`,
  `tools_round`, `rag_hit`, `outage_fallback` — JSON-contract reliability and
  outage rate are currently unmeasured.~~
  ✅ done 2026-08-25, `48c0193` — `JsonFormatter` now keeps `extra=`;
  `_log_ai_chat_turn` emits those keys (`ecb1993` format-only follow-up).
- ~~`constraint_patch` from the model must not silently overwrite fields
  already in `confirmed_fields` without explicit user action.~~
  ✅ done 2026-08-25, `ea3dacf` — `protect_confirmed=True` on the LLM merge
  path; chips/sliders still overwrite.
- ~~`find_places_near_point` (`tool_registry.py` ~444–458): add `ST_DWithin` +
  `LIMIT` — currently full bbox load + Python haversine.~~
  ✅ done 2026-08-25, `9a0f4e7`.
- ~~History load is `SELECT` all then `[-12:]` in Python (`session_service.py`
  ~537–549) — trim in the query while this file is open anyway.~~
  ✅ done 2026-08-25, `4a5b5d8` — `ORDER BY created_at DESC LIMIT 12` plus
  Phase 0 omit-filter so redacted turns do not fill the window.

## Phase 4 — Mobile: rebuild scope, cold start, swipe-deck jank

Priority: high. Source: mobile code review `PERF-11/12/15/17/20`.

Branch: `tourism-mobile` `fix/rebuild-scope-and-startup` (HEAD `b6ca5bd`).
`./scripts/validate.sh` 2026-08-25: dart format + `flutter analyze --fatal-infos`
clean; flutter test **213 passed**; macOS goldens **25 passed**.

- ~~`RouteHeroCard` (`:150-151`) and Home (`:413`, `:500`) watch the *entire*
  `sessionProvider` — any session field change (e.g. a token refresh)
  rebuilds every visible route card. Switch to `.select` on the specific
  field each site actually needs (mirror the narrower `PERF-15` shell watch
  once a pattern is established).~~
  ✅ done 2026-08-25, `b6ca5bd` — hero selects `(userId, displayName,
  avatarUrl)`; Home selects `(displayName, avatarUrl)` and passes the avatar
  into the header; shell uses `sessionProvider.select((s) => s.userId)`.
  Widget tests fail if a token rotate still rebuilds hero/Home.
- ~~`main.dart:12-15` — `await AppPush.bootstrap()` (Firebase) runs *before*
  `runApp`, delaying first frame on every cold start. Defer to after first
  frame or run non-blocking.~~
  ✅ done 2026-08-25, `b6ca5bd` — background handler still registers before
  `runApp`; `AppPush.bootstrap()` is scheduled on the first frame.
  `c8491db` is dart format only so `validate.sh` matches main.
- ~~`RouteSwipeDeck`'s `AnimatedBuilder` (`:437+`) rebuilds up to 3×
  `RouteHeroCard` (each re-running its `coverImage` `LayoutBuilder` +
  `MediaQuery` DPR lookup) on every drag/settle animation frame — the
  concrete mechanism behind "swipe deck jank on mid-range Android."~~
  ✅ done 2026-08-25, `b6ca5bd` — back cards reuse the same `RouteHeroCard`
  instance; covers are cached in `_RouteCardContent` (`route-cover-<id>`)
  so drag progress does not recreate `coverImage`. Visual tree/transforms
  unchanged; goldens still pass.

## Phase 5 — Mobile: AI-chat screen architecture + missing behavioral tests

Priority: high, larger lift than the phases above — plan as its own slice
rather than folding into a quick pass. Source: mobile code review `CODE-9`,
`CODE-13`, `CODE-15`.

Branch: `tourism-mobile` `fix/route-match-notifier` (HEAD `48f7deb`).
`./scripts/validate.sh` 2026-08-25: dart format + `flutter analyze --fatal-infos`
clean; flutter test **214 passed**; macOS goldens **25 passed**.

- ~~Extract a `RouteMatchNotifier` (session lifecycle, turn pipeline,
  `_ensureChatSession`/`_sendAiMessage`/`_acceptProposal`/reject,
  `_buildMatchParams`, constraint-patch apply) out of
  `_RouteMatchScreenState` (currently 1406 lines, ~30 mutable fields mixing
  domain logic with UI-only state like scroll sync and keyboard inset).
  UI-only state can stay in the State object.~~
  ✅ done 2026-08-25, `a9c0149` — chat pipeline lives in
  `RouteMatchNotifier`; form/scroll/keyboard stay in the State object.
  `48f7deb` is dart format only so `validate.sh` matches main.
- ~~Add behavioral tests against a fake `RouteMatchRepository` for
  `createSession` → `postMessage` → `acceptProposal`/`reject` — today only
  layout/golden tests and safety-keyword tests exist for this path; the
  actual chat pipeline has zero behavioral coverage.~~
  ✅ done 2026-08-25, `a9c0149`.
- ~~Add a behavioral test for the Travel+ activation flow: `_submit` →
  `activateTravelPlus` → `session.travelPlusActive` flips → AI mode unlocks.
  Same gap — goldens and nav-to-checkout exist, the actual state transition
  doesn't have a test.~~
  ✅ done 2026-08-25, `a9c0149` — checkout submit flips
  `travelPlusActive` and the AI mode CTA no longer gates to Travel+.

The Notifier extraction isn't just cleanup — it's what makes the two test
gaps above practical to close without standing up the whole screen widget
tree per test.

## Phase 6 — Mobile: place↔route "twin" drift

Priority: high but a design decision, not a quick patch — needs a call on
which screen is canonical before touching code. Source: mobile code review
`UX-1`, `UX-2`, building on mobile UX review finding 5.

Branch: `tourism-mobile` `fix/place-route-twins` (HEAD `57d7be6`).
Canonical = **route**. `./scripts/validate.sh` 2026-08-25: dart format +
`flutter analyze --fatal-infos` clean; flutter test **215 passed**; macOS
goldens **25 passed**. `place_hero_card.dart` is out of slice (not on main).

- ~~Shared today: only `CollapsingHeroSliver`/`CollapsingHeroAction`/
  `AppFavoriteIcon`/`RouteMapPreview`. Diverged into parallel copies: reviews
  (`PlaceReviewsSection` ~927 LOC vs. a private `_RouteReviewsSection` inside
  the 2666-line `route_details_screen.dart`), the audio/info card (tokens on
  place, hardcoded hex/radius on route), the collapse behavior itself
  (`scale:false` + different fade range on place vs. default `scale:true` on
  route), and loading state (place: raw `Container`s with no back button;
  route: `AppShimmer` skeleton). `place_hero_card.dart` (~202 LOC) vs.
  `route_hero_card.dart` (~801 LOC) also diverge in favorite-tap animation.~~
  ✅ done 2026-08-25, `2da6efc` — `EntityReviewsSection` (`entityId`,
  `kind`, `allowComposer`); `AudioGuideCard`; `HeroCollapseSpec.place` /
  `.route`; `DetailsHeroLoadingView(showBack: true)`. `57d7be6` is dart
  format only so `validate.sh` matches main.

This is why "make place match route" work (done earlier today) has to be
redone by hand every time — there's no shared implementation to inherit from,
only two screens copying each other's current state. Fixing this means
picking one canonical implementation for reviews/audio-card/collapse-params
and having both screens consume it, not just token-migrating route in place
(mobile UX review finding 5 alone won't stop the drift from recurring).

## Phase 7 — Mobile cleanup batch

Priority: medium. Source: mobile UX review findings 3/4/6/7; mobile code
review `CODE-3..5,10,12,14`, `SEC-2/3`, `UX-3,5,6,8`.

- `SearchScreen`/`/search`: confirm genuinely unreachable (no call sites for
  `AppRouteNames.search` as a push target) and delete rather than fix its
  missing back button.
- `AuthIdentityScreen`/`AuthOtpScreen`: confirm with product whether the
  missing back affordance during auth is intentional.
- A11y: not a per-file tooltip sweep — add a design-system contract
  (`AppIconButton` or equivalent in `core/design/components`) that *requires*
  a tooltip/`Semantics` label at the component level, so Settings and catalog
  controls (currently raw `Material`/`IconButton`) can't regress silently
  the way the 8-file list did.
- Cache-key/refetch cleanup: Home vs. catalog use different cache keys
  (`limit`/`sort` differ) so warm bootstrap doesn't feed Home
  (`CODE-3`); `listMyRoutes`/`getMyRoute` permanently bypass TTL (`CODE-4`);
  `publicProfileProvider` watches all of `sessionProvider` and refetches on
  any mutation including token refresh (`CODE-5`).
- Thin test coverage: no UI→session→gated-routes test for auth (`CODE-12`);
  no UI failure-path test for route publish (`CODE-14`).
- `SEC-2`: `file://` accepted in `avatarProvider`/`imageProvider` before/
  outside the allowlist. `SEC-3`: `AppEnvironment.local` allows any http(s)
  host in `resolveMediaUrl` — confirm this is dev-only and can't leak into a
  release config.
- Motion/transition split (`UX-3`, `UX-5`, `UX-6`): one `CollapsingHeroSliver`
  with three different fade/scale behaviors across place/route/profile;
  `_appTransitionPage`'s subtle vertical slide vs. the shell's `CupertinoPage`
  as two parallel transition languages; swipe-deck settle hardcoded to 340ms
  vs. `AppMotion.emphasized`'s 260ms.
- Parallel color-token audit (mobile UX review finding 7) — one-time diff
  against `core/design/app_colors.dart` to rule out silent drift across the
  3 feature-scoped token files.

## Phase 8 — Lower priority / batch when convenient

Priority: low, safe to defer indefinitely. Source: mobile UX review
finding 5/8/9; backend review `M-5`/`AI-11`; mobile code review `CODE-6..8`,
`SEC-5..7`, `UX-4`, `PERF-3..6,8,9,13,14,16,18,21,22,23,24`, `PERF-7,10,19`.

- `route_details_screen.dart` design-token migration — see Phase 6, this is
  the narrower "just the tokens" slice if the full twin-unification is
  deferred.
- `EntityReviewsSection` design-token migration (8 hardcoded colours, 13
  hardcoded radii). Phase 6 extracted it from the pre-token-pass reviews
  file, so the 2026-08-25 token pass on `place_reviews_section.dart` was lost
  in the unification — see the merge-status note at the top. Doing it here
  now fixes both place and route reviews at once, which is the payoff of the
  unification.
- Cross-module ORM-import cleanup (backend review `M-5`, ADR-001) — gradual,
  module by module; add the dependency test ADR-001 calls for once a first
  module is cleaned up.
- Remaining perf grab-bag: unbounded thumbnails (review-photo strips,
  avatars, search profile covers, route-detail gallery/cover), eager
  `Column`s instead of builders (notifications inbox, chat history list),
  more narrow `.select` opportunities (MyRoutes/RouteMatch/in-place search),
  coach-card blur-on-every-tick, collapsing-hero builder work per scroll
  frame.
- `SEC-5` — GoRouter path params (`:id`/`:placeId`/`:userId`) accepted
  without format validation before hitting the API. `SEC-6` — Firebase
  client keys in the bundle are expected, but confirm App Check / key
  restriction is configured ops-side. `SEC-7` — iOS Keychain accessibility
  is `first_unlock`, not `this_device`; confirm that's the intended
  trade-off.
- Bare-spinner → `AppSkeleton` sweep on remaining contained (non-full-screen)
  loading states; duplicated empty-state strings/component consolidation;
  page-dot animation constants unified (`UX-4`).
- Docs drift: `system-context.md`/home-lab docs still describe Gemini/Ollama;
  as-built is LM Studio (`AI-11`).

## Explicitly not now

- **No backend module extraction / microservices split** — ADR-001's
  original reasoning still holds (one team, one VPS, no proven independent
  scale need), and every module reachable from `route_builder` is the most
  cross-coupled part of the codebase, so splitting it today would produce a
  distributed monolith, not a clean service. Revisit only if the dependency-
  test cleanup in Phase 8 is done AND a concrete scale/ownership pressure
  shows up.
- **No RAG/embedder upgrade past `hash-v1`** — ADR-009's data-first
  sequencing still applies; locality/category coverage is the actual lever
  on match quality right now, not semantic retrieval.
- **No OSRM/road-network work** — tracked separately in
  [route-intelligence-roadmap.md](../route-intelligence-roadmap.md) §P2, not
  part of this remediation pass.
