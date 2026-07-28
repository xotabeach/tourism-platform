# Flutter testing guide

For `tourism-mobile`.

## Pyramid

- Many **unit** tests (domain parsing, mappers, pure logic).
- Targeted **widget** tests (home → catalog, loading/error).
- Few **integration** tests for critical flows.
- **Golden** tests for stable key screens/states and motion snapshots.

## Layers

| Layer | Approach |
| --- | --- |
| Domain | Pure Dart unit tests |
| Providers | `ProviderContainer` overrides |
| Repositories | Fake/mock API; fake repository for UI |
| Widgets | `flutter_test` + Riverpod overrides |
| Navigation | pump + GoRouter |

## Practices

- Prefer fake repositories over mocking Dio internals.
- Deterministic data (fixed ids/names like mock Crimea places).
- Cover async states: loading → data / error.
- Accessibility: semantics where critical controls exist.
- Golden frames use bundled fonts, local images, fixed device size and fixed
  animation progress.
- Review generated PNGs before accepting `--update-goldens`; never update
  baselines only to make CI green.

## Where pixel goldens run

Baselines are recorded on **macOS**. The Linux CI image renders text and blur
differently enough to fail every baseline by `1.5–7.6 %` of pixels, so a
tolerance large enough to pass would no longer catch real regressions.
Therefore `matchesGoldenFile` tests are skipped when the host is not macOS, and
CI keeps the host-independent expectations from the same file: responsive
overflow at `412×915` and `360×740` with text scale `1.3`, restrained swipe
travel with fixed `42×42` indicator, continuous post-swipe promotion,
standalone onboarding deck card, reduced motion and minimum `48×48` nav
targets.

Consequence: **pixel regressions are caught locally, not by CI.** Run the
goldens on macOS before pushing UI changes. Revisit this when the UI stabilises
(Phase 10) — the strict option is recording baselines inside the CI image.

The 2026-07-25 remediation run passed format, strict analysis, all 54 tests and
the macOS pixel goldens. Five compositor-related baselines were accepted only
after comparing their master/test images. The iOS Simulator build passed;
Android packaging was not run because the Android SDK was unavailable.

## Commands

```bash
flutter test
flutter test test/golden/ui_golden_test.dart
SKIP_PIXEL_GOLDENS=1 flutter test   # reproduce what CI runs
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib test
./scripts/validate.sh
```

Current UI golden coverage:

- Welcome and Home top;
- route list card and slider resting state;
- route-details top chrome with the shared shell CTA/compact Home composition;
- Android/iOS swipe onboarding, right progress and left progress;
- restrained pre-commit swipe travel and fixed `42×42` action indicator;
- continuous back-card promotion after a committed swipe;
- nav selected indices `0`, `1`, `2`;
- long-distance nav transition `0 → 4` at the liquid bridge frame;
- route-details pin selection without auto-scroll, tap-only gallery
  expansion/collapse, unaffected ordinary content scrolling, full-bleed
  recommendations and preserved shell navbar/branch state;
- one keyed navbar across the places catalog and place details, with Map
  selected after opening a route stop;
- iOS glass versus Android Material primary-control structure;
- native iOS/Android day/night launch resources;
- responsive smoke at `412×915` and `360×740` with text scale `1.3`;
- reduced motion and minimum `48×48` nav targets.

## Naming

```text
test_<behavior>_when_<condition>_<expected>
```

Widget example: `shows home and opens places catalog from mock data`.
