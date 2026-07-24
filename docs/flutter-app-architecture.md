# Flutter application architecture (Phase 5)

Целевая структура `tourism-mobile`. Стек остаётся **Riverpod + GoRouter + Dio**;
паттерны взяты из референса `set_up_flutter_app` (feature modules, shell
router, theme tokens, secure storage, error facade) **без** миграции на BLoC.

См. также: [flutter-code-style.md](flutter-code-style.md),
[security/mobile-security.md](security/mobile-security.md),
[repositories/tourism-mobile.md](repositories/tourism-mobile.md).

## Target layout

```text
lib/
├── main.dart
├── app.dart                          # MaterialApp.router + theme
├── core/
│   ├── config/                       # AppFlavor, AppConfig
│   ├── theme/                        # palette, ThemeExtension, AppTheme
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
| Theme layers | `AppColors` → semantic tokens → `ThemeData` |
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
| 1 | Places | `/places` | Catalog (Phase 3) |
| 2 | Routes | `/routes` | Editorial slider (Phase 4) |
| 3 | Favorites | `/favorites` | Placeholder → Phase 7 |
| 4 | Profile | `/profile` | Placeholder → Phase 6 |

Figma nav (Home / Explore / + / Map / Profile) пока **не** скопирован 1:1 —
текущие табы покрывают готовый домен. Place/route detail и onboarding —
**root** navigator (без bottom bar).

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
