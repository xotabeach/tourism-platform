# Flutter application architecture (Phase 5)

Целевая структура `tourism-mobile`. Стек остаётся **Riverpod + GoRouter + Dio**;
паттерны из референса `set_up_flutter_app` **без** миграции на BLoC.
As-built features — [progress.md](progress.md); контуры — [stack.md](stack.md).

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
    │   ├── network/                      # Dio + interceptors (JWT)
│   ├── errors/                       # AppFailure, mapping helpers
│   └── storage/                      # SecureStorage port + Keychain/Keystore impl
├── routing/
│   ├── app_router.dart               # GoRouter + StatefulShellRoute
│   └── shell/
│       └── app_shell_screen.dart     # bottom navigation scaffold
└── features/
    ├── home/
    ├── places/
    ├── routes/                       # catalog, reviews, publication
    ├── route_publish/                # user draft → submit
    ├── route_match/                  # form UI; builder API = Phase 8A
    ├── my_routes/                    # favorites / follows / history stub
    ├── favorites/                    # API favorites (also via my_routes)
    ├── profile/                      # durable; achievements mock
    ├── auth/
    ├── settings/                     # support, notifications, Travel+ mock
    └── search/
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

Onboarding (вне shell): `/welcome` → `/auth/identity` → `/auth/otp`.
Реальный OTP/JWT — as-built (Phase 6); mock auth только при
`DATA_SOURCE=mock`. После `onboardingCompleted` — shell.

| Index | Branch | Path | Content (as-built 2026-08) |
| --- | --- | --- | --- |
| 0 | Home | `/` | Home feed |
| 1 | Routes | `/routes` | Editorial swipe + details |
| 2 | Compose (+) | overlay | Опубликовать / Подобрать (не tab) |
| 3 | My routes | `/my-routes` | Favorites + follows; history placeholder |
| 4 | Profile | `/profile` | Durable profile; ranks/тп API; achievements mock |

Places catalog — вне tab bar (push / deep link). Publish: `/publish`.
Match form: `/match` (результат — facade до Phase 8A).

Nav follows the Figma segmented model: leading inactive glass segment, active
dark droplet, trailing inactive glass segment. Route details stay in the Routes
branch. One keyed shell navbar remains mounted across catalogs and detail
screens. On route-details entry it morphs into a compact Home droplet with the
route CTA; expanding restores the full navbar. Swipe onboarding is a
standalone first card in the route deck.

## Security hooks

- Secure storage holds refresh tokens (Phase 6 as-built).
- Staging/production `AppConfig` HTTPS-only (tested).
- Dio Bearer + single-flight refresh interceptor.
- No debug credentials in release paths.

## Freezed / codegen

Freezed + `json_serializable` остаются опциональны; as-built модели в основном
hand-written immutable. Не блокер для текущих экранов.

## Offline / local CRUD

Reference `LOCAL_CRUD_ARCHITECTURE` (sqflite service → repository) is a
**future** option after Drift/Isar spike. Not required for Phase 5 shell.
