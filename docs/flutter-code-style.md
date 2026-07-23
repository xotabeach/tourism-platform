# Flutter code style

Для `tourism-mobile`. Freezed / `json_serializable` / `build_runner` —
**Phase 5**; до этого — immutable hand-written models с `fromJson`.

См. [flutter-testing-guide.md](flutter-testing-guide.md),
[development-environment.md](development-environment.md).

## Feature-first layout

```text
lib/features/<feature>/
  application/   # providers
  domain/        # models, repository interfaces
  data/          # API / mock implementations
  presentation/  # screens, widgets
```

Shared: `lib/core/` (config, network), `lib/routing/`.

## Naming

| Вид | Стиль |
| --- | --- |
| Files | `snake_case.dart` |
| Classes | `PascalCase` |
| Providers | `fooProvider` / `fooListProvider` |
| Private | `_leadingUnderscore` |

## Imports

- `package:tourism_mobile/...` для app code.
- `directives_ordering` via analyzer.
- Не импортировать `implementation_imports` чужих пакетов.

## Riverpod / state

- Providers рядом с feature (`application/`).
- Immutable state; UI читает через `ref.watch`.
- Async screens: loading / error / empty / success (`AsyncValue.when`).

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

## Navigation

- GoRouter routes в `app_router.dart`; path constants на screens.
- Не хранить `BuildContext` в services.
- После `await` — проверять `mounted` / context safety.

## Widgets

- `const` где возможно.
- Не `dynamic` без причины.
- User-facing strings готовить к локализации (пока допустимы литералы с пометкой
  к Phase localization).

## Generated files (Phase 5+)

- `*.freezed.dart` / `*.g.dart` не править вручную.
- Не коммитить конфликты build_runner вслепую — перегенерировать.

## Errors

- Преобразовывать в typed UI state; не глотать exceptions молча.
