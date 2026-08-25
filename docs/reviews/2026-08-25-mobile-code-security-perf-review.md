# Mobile code, UI implementation, security & performance review

**Подпись:** ревью Cursor  
**Дата:** 2026-08-25  
**Репозиторий:** `tourism-mobile`  
**Reviewed revision:** `2e12d64` (`main`)  
**Режим:** read-only; код не менялся  

Входные документы:

- `flutter-app-architecture.md`, `flutter-design-system.md`,
  `flutter-testing-guide.md`, `flutter-code-style.md`
- Узкий UX-pass: [2026-08-25-mobile-ux-review.md](2026-08-25-mobile-ux-review.md)
  — **не повторяем** его находки (my_routes full-screen loading, raw
  exceptions, SearchScreen dead code, auth back, route_details tokens,
  IconButton tooltip list). Берём как baseline и копаем глубже.
- Бэклог: [2026-08-25-review-remediation-plan.md](2026-08-25-review-remediation-plan.md)
- Формат-близнец: [2026-08-25-backend-architecture-ai-review.md](2026-08-25-backend-architecture-ai-review.md)

---

## Executive summary

Кеш-обёртки `CachingPlacesRepository` / `CachingRoutesRepository` стоят
правильно (API-репозитории не конструируются в обход), но **карта
инвалидации (`app_data_refresh.dart`) не знает про `homePlacesProvider`** —
pull-to-refresh на Home → Локации и даже `AppDataRefreshScope.all` не
сбрасывают этот провайдер. Это уже не «стиль Riverpod», а stale UI после
явного жеста обновления.

Продуктовое ядро (ИИ-чат + Travel+) живёт в **god-State
`route_match_screen.dart` (~1406 LOC)** без Notifier для session/turn
pipeline; behavioral-тестов `createSession` / `postMessage` /
`acceptProposal` / `activateTravelPlus` **нет** — только виджет-лейаут,
safety heuristics и goldens.

Безопасность текстов (plain `Text`, нет Markdown/WebView) и хранения
токенов (refresh в Keychain/encrypted prefs, access в памяти) — сильные.
Главный реальный дефект: **чат рендерит `Image.network` с сырыми URL из
AI/API**, минуя `AppImages.resolveMediaUrl`. `test/security` при этом
зелёный — allowlist покрыт unit-ом, call-site в чате не регрессируется.

Place/route details — системный twin-drift: общие только hero-примитивы;
reviews / audio / collapse params / loading — параллельные копии. Place
сегодня чище по токенам, route остаётся «эталоном с долгом» (UX finding 5)
и держит monolith reviews внутри себя.

Что сломается / заболит первым при росте: (1) stale home places после
refresh, (2) чат-картинки + full-decode thumbs, (3) swipe-deck jank на
среднем Android, (4) Firebase bootstrap до `runApp`, (5) отсутствие
тестов на AI/Travel+ — регрессии долетят до пользователей без сигнала.

---

## 1. Код (архитектура, состояние, ошибки, тесты)

### 1.1 Riverpod / кеш

**Прямого обхода Caching\* нет.** Единственные конструкторы Api\*:

- `places_providers.dart:17-20` → `CachingPlacesRepository(ApiPlaces…)`
- `routes_providers.dart` — зеркально

Проблемы — в **инвалидации и ключах**, не в wiring.

| ID | Sev | Риск | Где |
| --- | --- | --- | --- |
| CODE-1 | P1 | Pull-to-refresh Home / `scope.all` **никогда не invalidate** `homePlacesProvider` → Локации остаются stale после явного refresh | `app_data_refresh.dart:116-118`, `:131-140`; consumer `home_screen.dart:329-339` |
| CODE-2 | P1 | `AppDataRefreshScope.myRoutes` не трогает `placesListProvider`, хотя экран смотрит favorite places через него | `app_data_refresh.dart:121-123`; `my_routes_screen.dart` (routes + places watch) |
| CODE-3 | P2 | Home vs catalog — разные cache keys (`limit: 20` vs default 50; routes `limit:100,sort:popular` vs catalog defaults) → warm bootstrap в `app.dart:47-51` не кормит home places | `places_providers.dart:23-33`; `caching_*_repository` key includes limit/sort |
| CODE-4 | P2 | `listMyRoutes` / `getMyRoute` permanently bypass TTL (`caching_routes_repository.dart` passthrough) | own profile always hits network |
| CODE-5 | P2 | `publicProfileProvider` `ref.watch(sessionProvider)` целиком → refetch (и uncached `listMyRoutes`) на любой session mutate, включая token refresh | `profile_providers.dart:163-199` |
| CODE-6 | P3 | `ApiCacheRegistry.register` только append; rebuild репозитория при смене config оставляет orphan caches | `api_cache.dart` registry |
| CODE-7 | P3 | `autoDispose` detail/search — re-run future при re-entry; TTL частично маскирует | `placeDetailProvider` и др. |

### 1.2 `route_match_screen` state growth

**CODE-9 · P1** — файл **1406 строк**, `_RouteMatchScreenState` с ~30
mutable полями: form/match params, session id, messages, typing/sending
flags + UI controllers.

`route_match_providers.dart` отдаёт repository + last match + sessions
list — **нет chat Notifier**. В State смешаны:

- **Domain (должно уйти в Notifier):** `_ensureChatSession`,
  `_sendAiMessage`, `_acceptProposal` / reject, `_buildMatchParams`,
  constraint patch apply, `_agentMessageFromResult`
- **UI-only (ок в State):** scroll/app-bar sync, keyboard inset,
  composer dirty, focus nodes

Это не «оправдано сложностью экрана» в смысле Flutter — сложность
продукта; **отсутствие контроллера** делает невозможным нормальный
behavioral-тест pipeline без подъёма всего экрана (см. CODE-13).

### 1.3 Сетевые ошибки

Паттерн `guardApiCall` → `AppFailure` соблюдён во всех Dio-репозиториях
(`api_places`, `api_routes`, `route_match`, auth, favorites, reviews,
notifications, support, publication).

| ID | Sev | Замечание |
| --- | --- | --- |
| CODE-10 | P2 | `secure_route_draft_repository.dart:19-27` — corrupt JSON → `null`, без log |
| CODE-11 | P3 | Presentation: `all_list_screen` / Travel+ checkout ловят `Object` и теряют `AppFailure.message` |

Молчаливого глотания в `lib/features/*/data/*` кроме draft — нет.

### 1.4 Тесты (golden ≠ бизнес-логика)

| Flow | Behavioral | Gap |
| --- | --- | --- |
| Favorites | сильное (`my_routes_*`, catalog state) | ок |
| Auth | session security + OTP keyboard + formatter | **CODE-12 P2** нет UI→session→gated routes |
| AI chat | models, chips, carousel, layout, AI safety keywords | **CODE-13 P1** нет `createSession`/`postMessage`/`accept`/`reject` против fake repo |
| Route publish | controller unit + geometry | **CODE-14 P2** нет UI failure path от publication API |
| Travel+ | goldens + nav до checkout UI | **CODE-15 P1** нет `_submit` → `activateTravelPlus` → `session.travelPlusActive` / AI unlock |

Goldens: `test/golden/*`, куски в publish — **не** считать покрытием оплаты/чата.

---

## 2. UI/UX реализация (не визуальный polish)

Известное из UX-ревью **не повторяем**. Ниже — implementation drift и
системный loading-паттерн.

### 2.1 Place ↔ route twin

Общее: `CollapsingHeroSliver` / `CollapsingHeroAction` / `AppFavoriteIcon` /
`RouteMapPreview`.

Не общее (копии / асимметрия):

| Surface | Place | Route |
| --- | --- | --- |
| Hero wrapper | inline `_PlacePhotoHeader` | `RouteCollapsingHeader` |
| Reviews | `PlaceReviewsSection` (~927 LOC) | private `_RouteReviewsSection` внутри `route_details_screen.dart` (**2666 LOC** файл) |
| Audio card | tokens (`AppRadii`/`AppColors`) ~548+ | hardcoded radius/hex ~880+ |
| Hero gradient | убран | остаётся в `route_collapsing_header.dart:162-177` |
| Collapse | `scale: false`; fade 0.02–0.64 | default `scale: true`; другие fade ranges |
| Loading | raw Containers, **без back** (~849-878) | `AppShimmer` skeleton; лучше при `initialRoute` |

**UX-1 · P1** — системный drift: правки «как на place» / «как на route»
расходятся при каждом проходе. Route одновременно эталон (UX finding 5) и
должник.

**UX-2 · P2** — другие эталоны с долгом: `places_catalog_screen` raw radii;
остаточный hex в reviews; `place_hero_card` vs `route_hero_card` (~202 vs
~801 LOC) с разным favorite bounce.

### 2.2 Анимации / transitions

| ID | Sev | Суть |
| --- | --- | --- |
| UX-3 | P2 | Один `CollapsingHeroSliver`, три поведения (place / route / profile fade+scale) |
| UX-4 | P3 | Page dots: place 180ms/8px vs route `AppMotion.fast`/10px |
| UX-5 | P2 | `_appTransitionPage` (subtle vertical) vs массовый `CupertinoPage` в shell — две языковые системы переходов |
| UX-6 | P2 | Swipe deck settle **340ms** hardcoded vs `AppMotion.emphasized` 260ms |

### 2.3 Full-screen loading (системный аудит)

Известный P1: `my_routes` — не повторяем.

| Screen | Loading заменяет chrome? | Вердикт |
| --- | --- | --- |
| Home | loading: **нет** (header в skeleton) | OK; **error: да** — **UX-7 P2** `home_screen.dart:316-319` / places twin |
| place/route details | body = весь UI; place loading без back | **UX-8 P2** |
| places/routes catalog | chrome снаружи | OK |
| profile | full skeleton, mimicked structure | приемлемо |
| achievements | filter/search только в `data:` | **UX-9 P2** |
| leaderboard / inbox / chat history | chrome снаружи | OK |
| route_match | нет screen-level `.when` body | OK |

**Системный антипаттерн:** `AsyncValue.when` как **корень Scaffold body**,
когда header/tabs живут внутри `data:`. Home loading починили; error и
my_routes / achievements — тот же класс.

### 2.4 A11y (архитектура, не список файлов)

UX-ревью перечислило IconButton без tooltip. Глубже: **нет обязательного
`AppIconButton` / design-system gate**, который требует `tooltip` /
`Semantics`. `Semantics`/`tooltip` сконцентрированы в route details /
route_match / shell; settings и часть catalog controls — сырой Material.
Это не 8 файлов с багом, а отсутствие контракта на уровне
`core/design/components`.

---

## 3. Безопасность

### 3.1 Глубина `test/security/` (не факт наличия)

| Файл | Глубина | Комментарий |
| --- | --- | --- |
| `api_failure_mapping_test` | **реальная** | не утекают URL/raw Dio в UI |
| `config_security_test` | **реальная** | HTTPS non-local, mock gate, placeholder hosts |
| `route_details_untrusted_content_test` | **сильная** | XSS-as-text + media allowlist на detail |
| `notifications_inbox_security_test` | **реальная** | XSS/`javascript:` as data + clamp |
| `search_history_security_test` | **узкая, реальная** | prefs length + XSS string as data |
| `auth_session_security_test` | **частичная** | refresh persist; нет assert «access ∉ SharedPreferences» |
| `public_profile_parse_security_test` | **частичная** | clamps / ignore role; нет render-as-text |
| `image_cache_security_test` | **мелкая** | scheme reject only; **нет host allowlist / chat call-site** |
| `secure_storage_port_test` | **тривиальная** | in-memory round-trip + type exists |
| `support_repository_security_test` | **тривиальная** | mock keeps strings; нет UI assert |
| `inbox_foreground_security_test` | **смешанная** | toast-as-Text полезен; badge — UX |
| `push_permission_security_test` | **слабая для appsec** | privacy UX |
| `display_name_policy_test` | **policy** | не classic appsec |
| `route_match_ai_safety_test` | **content safety** | crisis copy, не URL/token |

**Дыра:** зелёный `test/security` не ловит SEC-1.

### 3.2 Находки

| ID | Sev | Риск | Где |
| --- | --- | --- | --- |
| SEC-1 | P1 | AI/API `image_url` / `cover_url` / gallery → **`Image.network` без `resolveMediaUrl`** | `chat_place_chip.dart:41-46`; `chat_route_proposal_card.dart:241`, `:940` (единственные `Image.network` в `lib/`) |
| SEC-2 | P2 | `file://` принимается в `avatarProvider` / `imageProvider` до/вне allowlist; session avatar/cover с `/me` | `app_images.dart:170-171`, `:211-212` |
| SEC-3 | P2 | `AppEnvironment.local` — любой http(s) host в `resolveMediaUrl` | `app_images.dart:143-145` |
| SEC-4 | P2 | Security tests не регрессируют chat image call-sites | `image_cache_security_test.dart` |
| SEC-5 | P3 | GoRouter `:id` / `:placeId` / `:userId` без UUID gate → мусорные API calls | `app_router.dart` path params |
| SEC-6 | P3 | Firebase client keys в бандле — ожидаемо; нужен App Check / key restriction ops | `firebase_options.dart`, plist/json |
| SEC-7 | P3 | iOS `KeychainAccessibility.first_unlock` (не `this_device`) | `secure_storage_provider.dart:10` |

**Позитив:** refresh только в secure storage (`session_provider` write
refresh); access memory-only + Bearer interceptor; SharedPreferences —
search history; токены в логах не найдены; editorial/AI text — `Text`
only; Markdown/HTML/WebView в deps/`lib` нет.

---

## 4. Производительность

### 4.1 Изображения

Сегодняшний фикс `coverImage` (`memCacheWidth` only, bucketed,
`app_images.dart:250-267`) — корректен; **оба** `memCacheWidth`+`Height`
нигде больше не ставятся.

| ID | Sev | Где |
| --- | --- | --- |
| PERF-1 | P1 | Chat `Image.network` без cacheWidth на слотах 148×72 / gallery h=66 — full decode + SEC-1 |
| PERF-2 | P1 | Route detail gallery/cover через unbound `imageProvider` → full-bleed hero |
| PERF-3 | P2 | Review photo strips ~108px без resize (`place_reviews_section`, route reviews) |
| PERF-4 | P2 | Avatars via `avatarProvider` без decode bound |
| PERF-5 | P2 | Asset branch `coverImage` — `Image.asset` без `cacheWidth` |
| PERF-6 | P2 | Search profile covers — raw `Image` + provider без mem-cache |
| PERF-7 | P3 | Home precache `cacheWidth: 1080` vs bucketed coverImage → возможный double-decode |

### 4.2 Списки

Каталоги/home/favorites/chat transcript — в основном `ListView.builder` /
slivers — хорошо.

| ID | Sev | Где |
| --- | --- | --- |
| PERF-8 | P2 | Inbox: eager `Column` + `for` всех tiles |
| PERF-9 | P2 | Chat history: eager `Column` (provider limit 50) |
| PERF-10 | P3 | Universal search: map all results then `ListView.separated(shrinkWrap:)` |

### 4.3 Пересборки

| ID | Sev | Где |
| --- | --- | --- |
| PERF-11 | P1 | `RouteHeroCard` `ref.watch(sessionProvider)` целиком (`:150-151`) — любая session field → все видимые карточки |
| PERF-12 | P1 | Home `ref.watch(sessionProvider)` (`:413`, `:500`) — широкий rebuild |
| PERF-13 | P2 | MyRoutes watches весь `favoritesProvider` |
| PERF-14 | P2 | RouteMatch watches full session; CTA без `.select` |
| PERF-15 | P2 | Shell `ref.watch(sessionProvider).userId` без `.select` |
| PERF-16 | P2 | In-place search discovery watches top travelers + home routes + places list |

### 4.4 Холодный старт

| ID | Sev | Где |
| --- | --- | --- |
| PERF-17 | P1 | `main.dart:12-15` — `await AppPush.bootstrap()` (Firebase) **до** `runApp` |
| PERF-18 | P2 | `app.dart:47-51` eager watch 4 catalog providers на каждом build TourismApp |
| PERF-19 | P3 | `AppPerf.configureImageCache` в main — ок |

### 4.5 Animation jank

| ID | Sev | Где |
| --- | --- | --- |
| PERF-20 | P1 | `RouteSwipeDeck` `AnimatedBuilder` (`:437+`) пересобирает до 3× `RouteHeroCard` (coverImage LayoutBuilder + MediaQuery DPR) каждый кадр drag/settle |
| PERF-21 | P2 | Coach card: LayoutBuilder + blur path каждый tick |
| PERF-22 | P2 | Collapsing hero builder каждый scroll frame (media reload уже пофикшен) |
| PERF-23 | P3 | RouteMatch `MediaQuery.of` full dependency |
| PERF-24 | P3 | Deck asset precache без resize |

---

## 5. Сводная таблица находок

| ID | Sev | Область | Суть |
| --- | --- | --- | --- |
| CODE-1 | P1 | cache | `homePlacesProvider` вне refresh map |
| CODE-2 | P1 | cache | myRoutes refresh без places list |
| CODE-9 | P1 | arch | route_match god-State 1406 LOC |
| CODE-13 | P1 | tests | нет behavioral AI chat pipeline |
| CODE-15 | P1 | tests | нет Travel+ activate behavioral |
| SEC-1 | P1 | security | chat `Image.network` bypass allowlist |
| PERF-1 | P1 | perf | chat full-res decode (связан с SEC-1) |
| PERF-2 | P1 | perf | route hero unbound decode |
| PERF-11 | P1 | perf | RouteHeroCard watches full session |
| PERF-12 | P1 | perf | Home watches full session |
| PERF-17 | P1 | perf | Firebase before first frame |
| PERF-20 | P1 | perf | swipe deck rebuilds heroes per frame |
| UX-1 | P1 | ui | place↔route twin systemic drift |
| CODE-3..5,10,12,14 | P2 | code | cache keys, profile refetch, draft swallow, thin auth/publish tests |
| SEC-2..4 | P2 | security | file://, local allow-all, test gap |
| UX-2,3,5..9 | P2 | ui | token debt twins, motion/transition split, error/loading chrome |
| PERF-3..6,8,9,13..16,18,21,22 | P2 | perf | thumbs, eager lists, selects, bootstrap warm, scroll rebuilds |
| CODE-6..8,11; SEC-5..7; UX-4; PERF-7,10,19,23,24 | P3 | mixed | registry, UUID gate, Firebase keys, dots, precache |

---

## 6. Что сломается / заболит первым

1. **Stale Home Локации после pull-to-refresh** (CODE-1) — пользователь уже
   видел класс бага на loading flash; следующий — «обновил, а места те же».
2. **ИИ-чат изображения** (SEC-1 + PERF-1) — единственный обход media
   allowlist + full-decode на слабых GPU; security suite это не ловит.
3. **Swipe deck jank** (PERF-20 + PERF-11) — 3× тяжёлых карточки × session
   rebuilds на среднем Android.
4. **Cold start** (PERF-17) — Firebase до первого кадра на пушах.
5. **Регрессии AI / Travel+ без сигнала** (CODE-13/15 + CODE-9) —
   логика в State без тестов; чинить дорого, ломать дёшево.

Postgres/API listing на текущих объёмах — не первое мобильное узкое место;
узкие места клиентские: decode, deck frames, refresh map, chat media.

---

## 7. Приоритетный follow-up (для вливания в remediation plan)

1. **CODE-1 / CODE-2** — добавить `homePlacesProvider` (+ await) в
   `home`/`all`; `placesListProvider` в `myRoutes` invalidate/await.
2. **SEC-1 / PERF-1 / SEC-4** — все chat images через `AppImages.coverImage`
   / `resolveMediaUrl` + widget security regression на chip/proposal.
3. **PERF-20 / PERF-11 / PERF-12** — isolate deck transforms; `.select` на
   session fields в hero/home/shell.
4. **PERF-17** — Firebase/push bootstrap после первого кадра (или
   deferred).
5. **CODE-13 / CODE-15 / CODE-9** — извлечь `RouteMatchNotifier` (session +
   turns); behavioral tests с fake repository; то же для Travel+ activate.
6. **UX-1** — вынести shared reviews/audio/collapse params; один
   «эталон» без параллельных копий (иначе UX finding 5 размножается).
7. **UX-7** — Home error path с header, как loading.
8. A11y contract: `AppIconButton` с обязательным tooltip в design system
   (закрывает UX finding 6 системно, не файловым свипом).

Не сделано в этом ревью: правки кода, правки remediation plan (только
источник для Phase append).

---

*Конец отчёта. Ревью Cursor, 2026-08-25.*
