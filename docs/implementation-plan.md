# План реализации

План разбит на фазы. Phase 0–1 — foundation. Последующие фазы зависят от
принятия предыдущих acceptance criteria. Backlog в конце файла.

См. также: [application-business-logic.md](application-business-logic.md),
[development-conventions.md](development-conventions.md).

## Phase 0 — Repository audit and conventions

**Цель:** зафиксировать ответственность репозиториев, conventions и продуктовую
документацию без переписывания рабочего skeleton.

| Область | Задачи |
| --- | --- |
| Backend | Аудит структуры; не добавлять бизнес-модули |
| Mobile | Аудит feature-first skeleton |
| Infrastructure | Зафиксировать compose в tourism-platform; GitLab CI primary |
| API contracts | Нет |
| Database | Нет |
| Tests | Существующие validate scripts |
| Acceptance | Docs + conventions + README отражают 4-repo модель |
| Dependencies | Нет |
| Риски | Дублирование docs между workspace и platform |
| Не входит | Бизнес-фичи, удаление `.github` wholesale, push |

## Phase 1 — Local infrastructure

**Цель:** воспроизводимый local stack (Postgres/PostGIS, Redis, MinIO, Mailpit)
и закрытие gaps backend foundation (Redis ready, health paths, Dockerfile).

| Область | Задачи |
| --- | --- |
| Backend | Redis settings/ready; `/health/live`, `/health/ready`; Dockerfile; CI |
| Mobile | Format check в validate (опционально минимально) |
| Infrastructure | Compose healthchecks, `.env.example`, безопасный Makefile |
| API | Health only |
| Database | Существующая PostGIS migration |
| Tests | Health tests; compose config |
| Acceptance | `make up` поднимает deps; backend ready видит DB+Redis; CI зелёный локально |
| Dependencies | Phase 0 |
| Риски | Image tag drift |
| Не входит | Deploy, secrets, Kafka, business modules |

## Phase 2 — Backend foundation

**Цель:** слои pragmatic clean architecture, logging, error model, `/api/v1`
prefix, базовые module packages без полной бизнес-логики.

| Область | Задачи |
| --- | --- |
| Backend | Shared DB base, error handlers, JSON logs, module layout |
| Mobile | Нет |
| Infrastructure | Нет |
| API | Versioned empty router skeleton |
| Database | Meta/schema conventions |
| Tests | Smoke + lint |
| Acceptance | App стартует с `/api/v1` и health |
| Dependencies | Phase 1 |
| Не входит | Auth, places, routes |

## Phase 3 — Geography and places

**Цель:** Country/Region/Locality, categories, places catalog + detail API.

| Область | Задачи |
| --- | --- |
| Backend | Models, migrations, list/detail endpoints, seed Crimea |
| Mobile | Places catalog/detail screens + repository interfaces/mocks |
| Infrastructure | Нет |
| API | `/api/v1/geography/*`, `/api/v1/places/*` |
| Database | geography + places tables |
| Tests | API + domain invariants |
| Acceptance | Можно листать места Крыма и открыть карточку |
| Dependencies | Phase 2 |
| Не входит | Routes, auth-required favorites |

## Phase 4 — Editorial routes

**Цель:** публичные editorial routes, фильтры, карточка маршрута с stops.

| Область | Задачи |
| --- | --- |
| Backend | Unified `Route` with `source=editorial`; filters; geometry |
| Mobile | Routes catalog/detail |
| Infrastructure | Нет |
| API | `/api/v1/routes` |
| Database | routes, route_stops |
| Tests | Filter + publication invariants |
| Acceptance | Каталог и карточка редакционного маршрута |
| Dependencies | Phase 3 |
| Не входит | Generation, execution |

## Phase 5 — Flutter application foundation

**Цель:** navigation shell, themes Material 3, Dio client, env flavors,
repository pattern ready for real API.

| Область | Задачи |
| --- | --- |
| Backend | Нет (contracts already) |
| Mobile | Splash/Welcome/Home shell; GoRouter; Dio; Freezed models |
| Infrastructure | Нет |
| API | Consume existing |
| Database | Нет |
| Tests | Widget/golden smoke |
| Acceptance | Навигация по mock data без привязки UI к mocks |
| Dependencies | Phase 3–4 contracts желательны |
| Не входит | Pixel-perfect design |

## Phase 6 — Authentication

**Цель:** регистрация, вход, secure token storage, профиль read/update.

| Область | Задачи |
| --- | --- |
| Backend | identity + users; sessions/JWT (решение в ADR) |
| Mobile | Sign In/Up, Profile, secure storage |
| Infrastructure | Mailpit для email verify (local) |
| API | `/api/v1/auth/*`, `/api/v1/me` |
| Database | users, credentials, sessions |
| Tests | Auth flows |
| Acceptance | Пользователь регистрируется и видит профиль |
| Dependencies | Phase 2 |
| Не входит | OAuth providers (можно позже), SSO |

## Phase 7 — Favorites and profile

**Цель:** сохранение мест и маршрутов, список избранного.

| Область | Задачи |
| --- | --- |
| Backend | favorites module |
| Mobile | Favorites screen |
| API | `/api/v1/favorites/*` |
| Database | favorite_places, saved_routes |
| Tests | Ownership invariants |
| Acceptance | Save/unsave place and route |
| Dependencies | Phase 4, Phase 6 |
| Не входит | Social sharing |

## Phase 8 — Route builder

**Цель:** простая генерация маршрута с pipeline стадий, mock RoutingProvider,
entitlement/quota hooks (config free plan).

| Область | Задачи |
| --- | --- |
| Backend | Validation→…→Persistence pipeline; failure codes; UsageCounter |
| Mobile | Builder form + result |
| Infrastructure | Нет production routing keys |
| API | `/api/v1/route-builder/*` |
| Database | generation requests, generated routes as `Route(source=generated)` |
| Tests | Pipeline unit + quota |
| Acceptance | Генерация private route или понятный failure_code |
| Dependencies | Phase 3–4, Phase 6; entitlements stub |
| Не входит | ML, paid plans, multi alternatives (кроме stub entitlement) |

## Phase 9 — Route execution

**Цель:** старт прохождения, visited/skipped stops, история.

| Область | Задачи |
| --- | --- |
| Backend | RouteExecution model + API |
| Mobile | Active Route screen |
| API | `/api/v1/route-executions/*` |
| Database | route_executions |
| Tests | Status transitions |
| Acceptance | Пройти маршрут и увидеть history |
| Dependencies | Phase 4, Phase 6 |
| Не входит | Live GPS tracking productization |

## Phase 10 — Stabilization and staging

**Цель:** seed контент, staging deploy prep в tourism-platform, CI hardening.

| Область | Задачи |
| --- | --- |
| Backend | Seed scripts, perf smoke |
| Mobile | Point to staging API |
| Infrastructure | Helm/manifests draft; no production deploy |
| Acceptance | Staging smoke пройден |
| Dependencies | Phases 6–9 |
| Не входит | Production cutover |

## Phase 11 — User-created routes

**Цель:** private user routes (draft/active), без публичной модерации.

| Acceptance | Пользователь создаёт и сохраняет private route |
| Dependencies | Phase 8–9 |
| Не входит | Moderation, public listing |

## Phase 12 — Travel+ foundations

**Цель:** Plan/Subscription/EntitlementService config; feature flags; без оплаты.

| Acceptance | Free quotas enforced via service; Travel+ flag в dev |
| Dependencies | Phase 8 |
| Не входит | Store billing |

## Phase 13 — Trip Planner

**Цель:** Trip / TripDay / TripItem docs→API; attach Route to TripItem.

| Acceptance | Создать поездку и прикрепить route |
| Dependencies | Phase 12 entitlements `trip_planner_enabled` |
| Не входит | Collaborative trips, hotel booking |

---

## Backlog

Приоритеты: `P0` (MVP), `P1`, `P2`, `Future`.

| Type | ID | Title | Priority | Repository | Dependency | Acceptance criteria |
| --- | --- | --- | --- | --- | --- | --- |
| EPIC | E0 | Foundation docs and conventions | P0 | tourism-platform | — | Docs merged; 4-repo model documented |
| technical task | T0.1 | Business logic + implementation plan | P0 | tourism-platform | — | Files present; validate.sh lists them |
| technical task | T0.2 | Development conventions | P0 | tourism-platform | — | Branches/commits/MR/API versioning documented |
| EPIC | E1 | Local infrastructure | P0 | tourism-platform | E0 | Compose up healthy |
| technical task | T1.1 | Compose PostGIS Redis MinIO Mailpit | P0 | tourism-platform | — | Healthchecks pass |
| technical task | T1.2 | Backend Redis + health live/ready | P0 | tourism-backend | T1.1 | Ready checks DB and Redis |
| technical task | T1.3 | Backend Dockerfile + CI build | P0 | tourism-backend | T1.2 | Image builds without push |
| EPIC | E2 | Backend modular foundation | P0 | tourism-backend | E1 | `/api/v1` + layers |
| EPIC | E3 | Geography and places | P0 | tourism-backend, tourism-mobile | E2 | Catalog + detail |
| user story | US3.1 | As a traveler I browse Crimea places | P0 | tourism-mobile | E3 | See list and open card |
| EPIC | E4 | Editorial routes catalog | P0 | tourism-backend, tourism-mobile | E3 | Filter + detail |
| user story | US4.1 | As a traveler I open a prepared route | P0 | tourism-mobile | E4 | See stops and metadata |
| EPIC | E5 | Flutter app shell | P0 | tourism-mobile | E2 | Navigation + Dio ready |
| EPIC | E6 | Authentication | P0 | tourism-backend, tourism-mobile | E2 | Register/login/profile |
| user story | US6.1 | As a user I create an account | P0 | tourism-mobile | E6 | Session persisted securely |
| EPIC | E7 | Favorites | P0 | tourism-backend, tourism-mobile | E4, E6 | Save place/route |
| EPIC | E8 | Route builder | P0 | tourism-backend, tourism-mobile | E3, E6 | Generate or failure_code |
| technical task | T8.1 | RoutingProvider mock | P0 | tourism-backend | E8 | Swap-ready interface |
| technical task | T8.2 | EntitlementService config free plan | P1 | tourism-backend | E8 | Quotas from config |
| EPIC | E9 | Route execution | P0 | tourism-backend, tourism-mobile | E4, E6 | Start/complete/history |
| user story | US9.1 | As a traveler I mark visited stops | P0 | tourism-mobile | E9 | Progress updates |
| EPIC | E10 | Staging stabilization | P1 | tourism-platform, all | E6–E9 | Staging smoke |
| EPIC | E11 | User-created private routes | P1 | tourism-backend, tourism-mobile | E8 | Private CRUD |
| EPIC | E12 | Travel+ foundations | P2 | tourism-backend | E8 | Entitlements without billing |
| EPIC | E13 | Trip Planner | Future | tourism-backend, tourism-mobile | E12 | Trip with Route items |
| user story | US-F1 | Publish route for moderation | Future | all | E11 | ModerationStatus flow |
| user story | US-F2 | Subscribe to Travel+ | Future | all | E12 | Store purchase |
| technical task | T-F1 | Kafka activation | Future | tourism-platform | ADR-005 | Only with real consumers |

### MVP scope (сводка)

P0 epics E0–E9 + необходимые technical tasks. UI — технический Material 3.

### Travel+ scope (будущее)

E12 + billing/store + расширенные quotas/alternatives/offline/export.

### Trip Planner scope (будущее)

E13 + collaborative trips + rich TripItem types (accommodation, transport).
