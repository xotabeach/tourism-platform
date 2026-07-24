# Flutter application architecture (Phase 5)

Целевая структура `tourism-mobile`. Стек остаётся **Riverpod + GoRouter + Dio**;
паттерны взяты из референса `set_up_flutter_app` (feature modules, shell
router, theme tokens, secure storage, error facade) **без** миграции на BLoC.

См. также: [flutter-code-style.md](flutter-code-style.md),
[flutter-design-system.md](flutter-design-system.md),
[security/mobile-security.md](security/mobile-security.md),
[repositories/tourism-mobile.md](repositories/tourism-mobile.md).

## Target layout

```text
lib/
├── main.dart
├── app.dart                          # MaterialApp.router + theme
├── core/
│   ├── config/                       # AppFlavor, AppConfig
│   ├── design/                       # semantic tokens, glass, controls, motion
│   ├── theme/                        # Material ThemeData + compatibility exports
│   ├── network/                      # Dio + interceptors (auth later)
│   ├── errors/                       # AppFailure, mapping helpers
│   └── storage/                      # SecureStorage port + Keychain/Keystore impl
├── routing/
│   ├── app_router.dart               # GoRouter + StatefulShellRoute
│   └── shell/
│       └── app_shell_screen.dart     # bottom navigation scaffold
└── features/
    ├── home/
    ├── places/                       # domain / data / application / presentation
    ├── routes/                       # Phase 4+ catalog (placeholder OK in 5)
    ├── favorites/                    # Phase 7 placeholder
    └── profile/                      # Phase 6 placeholder
```

Per feature (unchanged rule):

```text
features/<name>/
  application/     # Riverpod providers / notifiers
  domain/          # models + repository interfaces
  data/            # API / mock / local adapters
  presentation/
    screens/
    widgets/       # formerly “parts” in the reference repo
```

## What we adopt from the reference

| Idea | How we apply it |
| --- | --- |
| Feature-first folders | Keep; already in use |
| `common/services` | As `core/` (config, theme, network, storage, errors) |
| Theme layers | semantic `core/design` tokens → `ThemeData` |
| Shell + tabs | `StatefulShellRoute.indexedStack` |
| Full-screen details | nested route + `parentNavigatorKey` |
| Secure storage wrapper | Riverpod provider over `flutter_secure_storage` |
| Error facade | typed `AppFailure`; no secrets in messages |
| Agent docs / BLoC | **Not adopted** — stay on Riverpod |

## What we explicitly do not adopt

- `flutter_bloc` / Cubit as primary state
- Manual singleton `DiContainer` (Riverpod is DI)
- `dartz` Either as mandatory (optional later; prefer typed failures + `AsyncValue`)
- Blind `make setup` (destructive overwrite)
- Shipping `.env` secrets as Flutter assets
- Sentry / slang until product need (can add later without layout change)

## Navigation shell (MVP tabs)

Onboarding (вне shell): `/welcome` → `/auth/identity` → `/auth/otp` (mock UI;
реальный auth — Phase 6). После `onboardingCompleted` — shell.

| Index | Branch | Path | Phase content |
| --- | --- | --- | --- |
| 0 | Home | `/` | Home feed (design) |
| 1 | Routes | `/routes` | Editorial swipe slider (Phase 4/5) |
| 2 | Route Builder | `/favorites` | Placeholder → Phase 8A |
| 3 | Map / Places | `/places` | Catalog (Phase 3) |
| 4 | Profile | `/profile` | Placeholder → Phase 6 |

Nav follows the Figma segmented model: leading inactive glass segment, active
dark droplet, trailing inactive glass segment. Place/route detail use the
**root** navigator. Swipe onboarding is a standalone first card in the route
deck, so its blur and interaction lock do not cover search, filters or bottom
navigation.

## Security hooks (Phase 5 foundation)

- Secure storage adapter ready; **no tokens written** until Phase 6.
- Staging/production `AppConfig` HTTPS-only (tested).
- Dio timeouts kept; auth interceptor stubbed/documented for Phase 6.
- No debug credentials in release paths.

## Freezed / codegen

Phase 5 may introduce Freezed + `json_serializable` for API models after the
shell/theme/storage foundation lands. Until then, hand-written immutable
models remain valid.

## Offline / local CRUD

Reference `LOCAL_CRUD_ARCHITECTURE` (sqflite service → repository) is a
**future** option after Drift/Isar spike. Not required for Phase 5 shell.
