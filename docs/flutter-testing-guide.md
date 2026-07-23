# Flutter testing guide

For `tourism-mobile`.

## Pyramid

- Many **unit** tests (domain parsing, mappers, pure logic).
- Targeted **widget** tests (home → catalog, loading/error).
- Few **integration** tests for critical flows.
- **Golden** tests only for stable key components — not every screen.

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

## Commands

```bash
flutter test
flutter analyze --fatal-infos
dart format --set-exit-if-changed lib test
./scripts/validate.sh
```

## Naming

```text
test_<behavior>_when_<condition>_<expected>
```

Widget example: `shows home and opens places catalog from mock data`.
