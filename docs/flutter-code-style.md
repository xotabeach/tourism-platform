# Flutter code style

Для `tourism-mobile`. Freezed / `json_serializable` / `build_runner` —
опционально в Phase 5 после shell; до этого — immutable hand-written models с
`fromJson`.

См. [flutter-app-architecture.md](flutter-app-architecture.md),
[flutter-design-system.md](flutter-design-system.md),
[flutter-testing-guide.md](flutter-testing-guide.md),
[development-environment.md](development-environment.md).

## Feature-first layout

```text
lib/
  core/            # config, design, theme, network, errors, storage
  routing/         # GoRouter + shell
  features/<feature>/
    application/   # Riverpod providers / notifiers
    domain/        # models, repository interfaces
    data/          # API / mock implementations
    presentation/
      screens/
      widgets/
```

Shared cross-feature code lives in `lib/core/`, not inside a random feature.
Do not introduce a parallel BLoC stack.

## Naming

| Вид | Стиль |
| --- | --- |
| Files | `snake_case.dart` |
| Classes | `PascalCase` |
| Providers | `fooProvider` / `fooListProvider` |
| Private | `_leadingUnderscore` |
| Route name constants | `*RouteNames` / screen `routePath` |

## Imports

- `package:tourism_mobile/...` для app code.
- `directives_ordering` via analyzer.
- Не импортировать `implementation_imports` чужих пакетов.

## Riverpod / state

- Providers рядом с feature (`application/`) или в `core/` for shared ports.
- Immutable state; UI читает через `ref.watch`.
- Async screens: loading / error / empty / success (`AsyncValue.when`).
- Prefer typed failures over untyped `Object?` in UI.

## Boundaries

```dart
// GOOD — UI → repository via provider
final places = ref.watch(placesListProvider);

// BAD — Widget creates Dio and parses JSON
```

- Widget не ходит в Dio напрямую.
- UI без domain business rules.
- Repository interface не зависит от mock/API impl.
- DTO/JSON mapping в data layer; domain models отдельно (или shared immutable
  classes до Freezed).
- Secure credentials only via `core/storage` (Keychain/Keystore-backed).

## Navigation

- GoRouter with `StatefulShellRoute` for main tabs.
- Path/name constants on screens or `*RouteNames`.
- Full-screen flows (details, auth): `parentNavigatorKey` on root navigator.
- Не хранить `BuildContext` в services.
- После `await` — проверять `mounted` / context safety.

## Theme

- Semantic palette, spacing, radii, shadows, typography and motion live in
  `core/design`.
- Brand typeface: **Rubik** (`AppFonts.rubik`, bundled
  `assets/fonts/Rubik-VariableFont_wght.ttf`). Logo wordmark via
  `AppTextStyles.logo`.
- Wire Material 3 via `AppTheme.light` / dark later.
- Prefer semantic tokens over hard-coded `Color(0x…)` in widgets.
- Reuse `AppGlassSurface` / pill / circle / icon button; do not stack multiple
  backdrop blurs when a parent already provides one.
- Respect `MediaQuery.disableAnimationsOf`; reduced motion uses short
  slide/crossfade without stretch or overshoot.

## Widgets

- `const` где возможно.
- Не `dynamic` без причины.
- User-facing strings готовить к локализации (пока допустимы литералы; slang
  optional later).
- Interactive targets are at least `48×48`; add labels and selected/toggled
  state to semantics.
- Keep image-heavy animated subtrees inside `RepaintBoundary` and precache
  deterministic local deck images.

## Generated files (when Freezed lands)

- `*.freezed.dart` / `*.g.dart` не править вручную.
- Не коммитить конфликты build_runner вслепую — перегенерировать.

## Errors

- Преобразовывать в typed UI state; не глотать exceptions молча.
- Не логировать tokens/passwords.
