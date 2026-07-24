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

## Commands

```bash
flutter test
flutter test test/golden/ui_golden_test.dart
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib test
./scripts/validate.sh
```

Current UI golden coverage:

- Welcome and Home top;
- route list card and slider resting state;
- swipe onboarding, right progress and left progress;
- restrained pre-commit swipe travel and fixed `42×42` action indicator;
- nav selected indices `0`, `1`, `2`;
- responsive smoke at `412×915` and `360×740` with text scale `1.3`;
- reduced motion and minimum `48×48` nav targets.

## Naming

```text
test_<behavior>_when_<condition>_<expected>
```

Widget example: `shows home and opens places catalog from mock data`.
