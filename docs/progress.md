# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 5 — Flutter foundation (UI по дизайну КрымТрип)
**Последнее обновление:** 2026-07-25

## Сводка фаз

| Phase | Название | Статус |
| --- | --- | --- |
| 0 | Repository audit and conventions | done |
| 1 | Local infrastructure | done |
| 2 | Backend foundation | done |
| 3 | Geography and places | done |
| 4 | Editorial routes | done |
| 5 | Flutter application foundation | in_progress |
| 5.5 | Environment foundation | in_progress |
| 5.6 | First remote test backend | in_progress |
| 6 | Authentication | pending |
| 7 | Favorites and profile | pending |
| 8A | Deterministic Route Builder | pending |
| 8B | AI-assisted Route Planning (experimental) | pending |
| 9 | Route execution | pending |
| 10 | Stabilization and staging | pending |
| 11 | User-created routes | pending |
| 12 | Travel+ foundations | pending |
| 13 | Trip Planner | pending |

Статусы: `pending` · `next` · `in_progress` · `done` · `blocked`.

## Что сделано

### Phase 0–2

См. историю выше / git log: docs, Compose, Redis ready, `/api/v1`, error
envelope, JSON logs.

### Phase 3 — Geography and places (2026-07-23)

- Миграция `0002_geography_and_places`: countries/regions/localities,
  categories/places/M2M/entrances/schedules/images; FK + GIST/btree/partial
  unique indexes.
- Документ схемы: [data-model-geography-places.md](data-model-geography-places.md).
- Seed `data/crimea_seed.json` + `scripts/seed_crimea.py` (idempotent, bulk
  `--file` / `--places-only`) — 20 мест Крыма.
- Read API: geography + categories + places list/detail.
- Integration tests против PostGIS/Redis; CI services postgis+redis.
- Mobile: Places catalog/detail, repository interface, mock + API
  implementations (`useMockData` в AppConfig). Freezed отложен на Phase 5.
- Compose `.env.example`: PostGIS `16-3.4` (multi-arch), ports `5433`/`6380`.

### Phase 4 — Editorial routes (2026-07-23)

- Миграция `0003_editorial_routes`: `routes`, `route_stops`, checks/indexes,
  LINESTRING geometry.
- Документ: [data-model-routes.md](data-model-routes.md).
- Seed: 3 editorial routes в `crimea_seed.json` + upsert в `seed_crimea.py`.
- Read API: `GET /api/v1/routes`, `GET /api/v1/routes/{id}` (только public
  editorial/active); фильтры region/transport/difficulty/q.
- Mobile: routes feature (domain/data/application/presentation), catalog +
  detail, вкладка «Маршруты» в shell.

### Repository code review and hardening (2026-07-25)

- Добавлены отдельные Cursor skills для evidence-first backend/mobile review на
  основе workspace rules, security baseline и code style.
- Backend и mobile проверены раздельно; отчёты и общий порядок исправлений:
  [backend review](reviews/2026-07-25-backend-code-review.md),
  [mobile review](reviews/2026-07-25-mobile-code-review.md),
  [remediation plan](reviews/2026-07-25-code-review-remediation-plan.md).
- Backend: readiness/validation больше не отражают внутренние исключения и
  входные значения; public routes не раскрывают draft places; list ordering
  стабилен; PostGIS coordinates загружаются bulk; CI integration gate fail
  closed; coverage floor 75%.
- Backend gate: Ruff/MyPy/pip-audit passed; Pytest `17 passed, 24 skipped`,
  coverage 79.89%. Пропуски связаны с недоступным локальным Docker daemon.
- Mobile: release выбирает production policy и требует HTTPS `API_BASE_URL`;
  Android main manifest содержит `INTERNET`, debug signing fallback удалён;
  remote media ограничены trusted HTTPS origin.
- Right swipe теперь обновляет in-session favorites state, chips/search
  работают, detail providers auto-dispose. Durable favorites остаются Phase 7.
- Dio/JSON failures преобразуются в safe typed state; экраны показывают
  стабильную ошибку и retry вместо raw exception.
- Glass card alpha переведена с parent `Opacity` на compositor-safe color
  filtering; пять затронутых macOS goldens сравнены и обновлены осознанно.
- Mobile gate: format/analyze passed, 54 tests and all macOS pixel goldens
  passed; iOS Simulator build passed. Android SDK отсутствует.

## Что дальше

### Phase 5 — Flutter foundation (продолжение)

Сделано по comparison screenshots Figma:
- `core/design`: semantic colors, typography, spacing, radii, shadows, motion
- Reusable glass surfaces/pills/circles/icon buttons; full Rubik variable font
- Welcome → mock auth (имя/телефон → OTP + согласия) → Home
- Native launch screen: адаптивные iOS/Android day/night resources с
  `КРЫМТРИП`, заранее отрисованным из локального Rubik; Android 12 splash
  настроен без новой зависимости.
- Welcome/Home: исправлены crop, scrim, typography, search, hero, travelers
- Route card: Figma hierarchy (author/tags/rating/locality/distance);
  difficulty остаётся только в swipe deck и route details, но не в Home list
- Routes: responsive stacked swipe deck, vertical onboarding, green/burgundy
  drag states, restrained rotation/translation, fixed compact indicators,
  spring-back, committed-swipe haptics и непрерывное продвижение
  `back → front` без скачка геометрии.
- Swipe onboarding — самостоятельная первая карточка колоды, а не overlay
  внутри `RouteHeroCard`; две маршрутные карточки остаются видны за ней,
  search/filter/nav остаются вне блюра.
- Экраны сверены со свежими Figma-скринами: главная (48 px серые контролы,
  баннер 246, ритм), подтверждение номера (серые поля кода: заполненное поле
  плавно вырастает с 58 до 70 px и остаётся высоким, при стирании возвращается;
  согласия в две строки), карточка свайпа (заголовок 24, тёмные
  пилюли, контурные молнии, веерная стопка).
- Route details переписан по дизайну: медиа-шапка с пагинацией, белый лист с
  автором, заголовком, описанием, аудиогидом, тегами, параметрами, картой,
  остановками, full-bleed блоком «Похожие маршруты», рейтингом и отзывами.
  Тап по фото плавно раскрывает и закрывает галерею на `0.66` высоты экрана;
  вертикальные жесты всегда остаются обычным scroll контента и не меняют
  галерею. Выбор точки только синхронно подсвечивает карту и остановку, без
  reposition страницы. Рекомендации открываются через Hero/reveal.
- Route details остаётся внутри Routes branch и использует тот же keyed shell
  navbar: за 560 мс сегменты схлопываются внутрь до home-капли, а «Пройти
  маршрут» занимает освободившийся правый слот. При раскрытии CTA уезжает
  наверх и кратко растягивается, а пункты navbar выходят из центра капли;
  состояние branch сохраняется.
- Каталог мест и подробности точки также используют общий shell navbar.
  Переход из остановки маршрута переключает его на Map branch, а возврат к
  каталогу не пересоздаёт navbar.
- Основные и круглые команды на iOS используют reusable blur-glass surface;
  Android сохраняет текущие Material-кнопки.
- Segmented floating nav: leading/trailing glass + interrupt-safe liquid
  droplet, semantics, 48 px targets, reduced motion
- Long-distance nav transitions no longer draw a bridge across the full bar:
  the previous droplet contracts by travel distance and the liquid tail is
  capped locally. A reviewed `0 → 4` mid-animation golden covers the original
  artifact.
- Figma-exported SVG icon set integrated through central `AppIconography`;
  transparent 128 px white/ink/muted runtime assets, no new dependency
- 13 reviewed goldens at `393×852`, включая верх route details, отдельный iOS
  glass coach и navbar `0 → 4` mid-frame; responsive checks at `412×915` and
  `360×740` with text scale `1.3`
- Pixel goldens run on macOS only: Linux CI differs by `1.5–7.6 %` of pixels,
  so CI keeps the host-independent checks and visual regressions are caught
  locally. Reproduce CI with `SKIP_PIXEL_GOLDENS=1 flutter test`.
  See [flutter-testing-guide.md](flutter-testing-guide.md).
- Auth — UI only; реальный OTP/токены — Phase 6
- **Mock-first DX:** local `DATA_SOURCE=mock` по умолчанию (8 places /
  3 routes + local assets). Docker/backend не нужны для UI.
  API: `flutter run --dart-define=DATA_SOURCE=api`.
- Test/staging/production запускаются только с валидными
  `APP_ENV`/`API_BASE_URL`; release без environment выбирает production.
- Current mobile gate after navbar fix: format/analyze passed, `57 tests` and
  all 13 macOS pixel goldens passed.

Остаётся: сверка approximate values и original SVG через Figma Dev Mode,
device screenshot diff, performance profile на mid-range Android; Freezed
optional. Pixel-perfect статус не заявлен без этих проверок.
См. [flutter-app-architecture.md](flutter-app-architecture.md).

### Phase 5.5–5.6 — Environments and first remote test server

До Phase 6 нужно унифицировать `local/test/staging/production`, отделить
mobile data source и AI provider от runtime environment, затем развернуть
immutable backend image из `gamma` в test-контуре. Слабый узел использует
constrained Compose, swap, один worker, HTTPS reverse proxy, закрытые data
ports, миграционный job, health/smoke checks и off-host test backup. MinIO,
пользовательские данные и AI в этот контур не входят.

Подготовлено в коде: backend `APP_ENV` enum и immutable image с seed/media;
mobile `APP_ENV` + `DATA_SOURCE` с запретом mock вне local; GitLab publication
image по commit SHA; constrained test Compose и deploy script. Остаются
host bootstrap, TLS/DNS, remote deploy, rollback и backup/restore smoke.

Проверки 2026-07-26: backend validation `42 passed`, coverage 89.11%,
pip-audit без известных уязвимостей; runtime image собран локально, seed/media
проверены. Mobile validation `56 tests`, test/API iOS Simulator build passed.
Platform local и constrained test Compose config passed. Remote bootstrap ждёт
ротации первоначального пароля, SSH deploy key и подтверждённого TLS hostname;
host inventory и credentials в Git не сохраняются.

Remote bootstrap отложен владельцем 2026-07-26. Отдельный локальный bootstrap
key создан, но на сервер не установлен; сервер и его SSH/configuration не
изменялись. При возобновлении начать с восстановления VNC/root-доступа,
установки публичного ключа и проверки SSH host fingerprint. Не запрашивать и
не сохранять пароль в чате или repository.

См.
[environment-and-backend-deployment.md](environment-and-backend-deployment.md).

### Документировано (не реализовано): AI route planning

Архитектура и ADR-006: provider-neutral AI, Gemini experimental → Gemma + RAG,
editorial-first, form/chat → `NormalizedRouteRequest`, MCP отложен.
См. [ai-route-planning-architecture.md](ai-route-planning-architecture.md).
Реализация — Phase 8B+, не часть Phase 3/4.

## Блокеры и заметки

- Auth strategy: **ADR-007** (JWT access + opaque refresh for mobile; cookies
  later for web/admin). Implementation still Phase 6.
- Routing provider — open decision (ADR-004).
- Не коммитить `.tmp-ref-frames/` и локальные `.env`.
- AI architecture documented only; no Gemini/Gemma/MCP code yet.
- DX: style guides + Cursor workspace settings — see
  [development-environment.md](development-environment.md).
- Security: docs + Cursor skill/rule documented under
  [security/security-baseline.md](security/security-baseline.md). **Not**
  claimed complete; auth/Redis ACL/prod hardening still open.
- Release blockers: organization-owned Android signing and Android build check
  требуют CI secrets/Android SDK; physical-device Impeller profile не выполнен.

## Документировано (не реализовано): Security Baseline

Threat model, data classification, API/mobile/storage security docs, ADR-007,
incident response, CI recommendations. Foundation code: input limits, prod
placeholder-secret guard, security pytest, pip-audit job. Full auth — Phase 6.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`.
2. При завершении: итог в «Что сделано», таблицу обновить.
3. Блокеры писать сразу.
4. Детальный backlog — в implementation-plan.
