# План реализации

План разбит на фазы. Phase 0–1 — foundation. Последующие фазы зависят от
принятия предыдущих acceptance criteria. Backlog в конце файла.

См. также: [application-business-logic.md](application-business-logic.md),
[development-conventions.md](development-conventions.md),
[progress.md](progress.md) (живой статус: что сделано / что дальше),
[security/security-baseline.md](security/security-baseline.md).

## Security Baseline (cross-cutting)

**Цель:** security docs, threat model, secrets policy, secure defaults, Cursor
security skill/rule, CI foundation. **Не** считать security «done» только из-за
документации.

| Область | Задачи |
| --- | --- |
| Docs | `docs/security/*`, ADR-007 auth strategy |
| Tooling | Ruff security rules, pip-audit, security pytest, optional secret/image scan |
| Cursor | `.cursor/rules/security-baseline.mdc`, Skill, `/security-audit` command |
| Defaults | refuse local placeholder secrets in staging/production; input limits |
| Acceptance | Docs + skill present; local security tests green; CI job documented |
| Не входит | Full auth implementation, prod NetworkPolicy, DAST vs production |

Статус: documented + foundation checks; auth/authZ implementation — later phases.

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
| Security | Authorization/publication invariants; safe user-facing content fields; route data validation/limits |
| Acceptance | Каталог и карточка редакционного маршрута |
| Dependencies | Phase 3 |
| Не входит | Generation, execution |

## Phase 5 — Flutter application foundation

**Цель:** navigation shell, theme tokens, Dio/network foundation, secure
storage adapter, feature-first layout ready for Phase 4–7 screens.
Стек: **Riverpod** (не BLoC). Детали:
[flutter-app-architecture.md](flutter-app-architecture.md).

| Область | Задачи |
| --- | --- |
| Backend | Нет (contracts already) |
| Mobile | `StatefulShellRoute`; segmented animated nav; `core/design`, `core/theme`, `core/storage`, `core/errors`; Welcome/Home/route cards/swipe onboarding; Freezed optional after shell |
| Infrastructure | Нет |
| API | Consume existing places; routes when Phase 4 ready |
| Database | Нет (offline spike later) |
| Tests | Widget smoke through shell; secure-storage/HTTPS tests; deterministic UI goldens and responsive/reduced-motion checks |
| Security | Secure storage wiring; HTTPS-only non-dev; deep-link policy stub; no debug secrets |
| Acceptance | Tabs and segmented nav work; catalogs and route details keep one stateful shell nav; detail mode morphs the route CTA into the compact nav; native day/night launch is branded; swipe onboarding is the standalone first deck card; accepted 393×852 goldens; no BLoC migration |
| Dependencies | Phase 3 done; Phase 4 contracts желательны для Routes tab content |
| Не входит | Pixel-perfect claim without Figma/device diff; real auth; BLoC; Sentry/slang mandatory; Drift/Isar |

## Phase 5.5 — Environment foundation

**Цель:** единый типизированный контракт `local/test/staging/production` для
mobile, backend, CI и будущих AI providers.

| Область | Задачи |
| --- | --- |
| Backend | Typed `APP_ENV`; environment validation; separate DB/Redis/storage URLs |
| Mobile | `APP_ENV` + `DATA_SOURCE=mock\|api`; mock разрешён только local/tests |
| Infrastructure | Environment-scoped CI variables and safe config examples |
| AI | Provider policy documented independently from environment; automated tests use mock |
| Security | Reject local credentials and unsafe endpoints outside local |
| Acceptance | Configuration matrix covered by tests; `main` → production deploy, `gamma` → stage |
| Dependencies | Phase 5 foundation |
| Не входит | Real AI adapter; production secrets; server deployment |

См. [environment-and-backend-deployment.md](environment-and-backend-deployment.md).

## Phase 5.6 — First remote test backend

**Цель:** развернуть immutable image из `main` (GitLab environment
`production`) на существующем малом сервере без AI inference и production data.
Ветка `gamma` обслуживает environment `stage` (publish only, без SSH на сервер,
пока нет отдельного stage-хоста).

| Область | Задачи |
| --- | --- |
| Backend | Immutable container image; migration and API smoke jobs |
| Mobile | Test build points to deployed HTTPS API |
| Infrastructure | Constrained Compose, swap, reverse proxy/TLS, protected deploy, rollback |
| Data | Isolated disposable PostGIS/Redis; no MinIO; off-host test backup |
| Operations | Health, logs, resource/certificate alerts, restore exercise |
| Security | Private data ports; key-only SSH; non-root deploy; secret isolation |
| Acceptance | Deploy and rollback pass; test API works from mobile; backup restore verified |
| Dependencies | Phase 5.5; server inventory, domain and deployment access |
| Не входит | Production cutover; Kubernetes; self-hosted AI |

См. [environment-and-backend-deployment.md](environment-and-backend-deployment.md).

## Phase 6 — Authentication

**Цель:** регистрация, вход, secure token storage, профиль read/update.

| Область | Задачи |
| --- | --- |
| Backend | identity + users per ADR-007 (JWT access + opaque refresh) |
| Mobile | Sign In/Up, Profile, secure storage |
| Infrastructure | Mailpit для email verify (local) |
| API | `/api/v1/auth/*`, `/api/v1/me` |
| Database | users, credentials, sessions |
| Tests | Auth flows |
| Security | Argon2id; refresh rotation/reuse detection; revocation; rate limiting; auth security tests |
| Acceptance | Пользователь регистрируется и видит профиль |
| Dependencies | Phase 2; Security Baseline; ADR-007 |
| Не входит | OAuth providers (можно позже), SSO |

## Phase 6.5 — Internal ops admin (SQLAdmin)

**Цель:** server-rendered ops-админка для поддержки теста и ops: пользователи,
OTP-коды (пока нет SMS), права, диалоги поддержки. Реализация через
**SQLAdmin** (HTML UI на FastAPI/SQLAlchemy), а не ручные Jinja-табы и не SPA.
Делать **сразу после** OTP debug-code контура, до расширения Phase 8+.

| Область | Задачи |
| --- | --- |
| Backend | SQLAdmin at `/admin`; session cookie + Origin/Referer CSRF; roles allowlist |
| UI | SQLAdmin ModelViews: users, OTP challenges (`debug_code` local/test only), principals/roles, support threads/replies |
| API | Internal `/admin/*` (not public mobile contract); no ORM dump of secrets; audit log of admin actions |
| Database | `admin_principals`, `admin_role_bindings`, `admin_audit_events`; reuse support tables |
| Security | Separate from mobile JWT (Argon2id principals); login rate limits; no OTP codes in staging/prod |
| Acceptance | Operator can look up a test user, read a live OTP on the test contour, and reply in support chat |
| Dependencies | Phase 6 (identity + OTP), existing support chat persistence |
| Не входит | Full CMS, billing, Travel+ entitlements UI, public web app |

## Phase 7 — Favorites and profile

**Цель:** сохранение мест и маршрутов, список избранного; каркас профиля
из Phase 6 заполняется избранным. Геймификация (звание / тп / достижения) —
отдельная Phase 14.

| Область | Задачи |
| --- | --- |
| Backend | favorites module |
| Mobile | Favorites screen; profile показывает favorites entry points |
| API | `/api/v1/favorites/*` |
| Database | favorite_places, saved_routes |
| Tests | Ownership invariants |
| Security | Object ownership; BOLA negative tests; private favorites authZ |
| Acceptance | Save/unsave place and route |
| Dependencies | Phase 4, Phase 6 |
| Не входит | Social sharing; ranks/achievements (Phase 14) |

## Phase 8A — Deterministic Route Builder

**Цель:** нормализованный запрос, editorial matching, candidate selection,
constraints, scoring, mock `RoutingProvider`, persistence, failure codes,
foundation для fallback (без LLM).

| Область | Задачи |
| --- | --- |
| Backend | Validation→editorial match→candidates→score→RoutingProvider→persist; UsageCounter stub |
| Mobile | Builder form + result |
| Infrastructure | Нет production routing keys |
| API | `/api/v1/route-builder/*` |
| Database | generation requests, `Route(source=generated)` |
| Tests | Pipeline unit + quota + failure codes |
| Acceptance | Генерация private route или понятный `failure_code` |
| Dependencies | Phase 3–4, Phase 6; entitlements stub |
| Security | Generation quotas; external provider timeouts/limits |
| Не входит | LLM/Gemini, conversational chat, paid plans |

См. [ai-route-planning-architecture.md](ai-route-planning-architecture.md),
[ADR-006](decisions/ADR-006-ai-assisted-route-planning.md).

## Phase 8B — AI-assisted Route Planning (experimental)

**Цель:** provider-neutral AI ports, mock + Gemini adapter, structured output,
tool calling через internal ToolRegistry, validation, bounded repair,
deterministic fallback, metrics, feature flag. **Без production SLA.**

| Область | Задачи |
| --- | --- |
| Backend | `AIPlanningProvider`, schemas, validator/repair, usage metadata |
| Mobile | Нет отдельного AI UI (тот же builder result + warnings) |
| Infrastructure | Env placeholders only; no GPU |
| API | Тот же route-builder; AI за flag, не отдельные mobile AI endpoints |
| Tests | Mock provider contract + invalid output → fallback |
| Security | AI/RAG security; prompt/tool validation; no PII in prompts; tool allowlists |
| Acceptance | Flag on: AI proposal проходит validation или fallback; flag off: 8A |
| Dependencies | Phase 8A |
| Не входит | Gemma deploy, RAG prod, MCP, billing, chat dialogue |

## Phase 8 — Route builder (umbrella)

Phase 8 в progress/backlog = **8A + 8B**. MVP P0 требует 8A; 8B — P1
experimental.

## Phase 9 — Route execution

**Цель:** старт прохождения, visited/skipped stops, история.

| Область | Задачи |
| --- | --- |
| Backend | RouteExecution model + API |
| Mobile | Active Route screen |
| API | `/api/v1/route-executions/*` |
| Database | route_executions |
| Tests | Status transitions |
| Security | Location privacy; route-execution authorization; retention |
| Acceptance | Пройти маршрут и увидеть history |
| Dependencies | Phase 4, Phase 6 |
| Не входит | Live GPS tracking productization |

## Phase 10 — Production readiness and stabilization

**Цель:** усилить уже работающий staging-контур и подготовить контролируемый
production cutover.

| Область | Задачи |
| --- | --- |
| Backend | Seed scripts, perf smoke |
| Mobile | Point to staging API |
| Infrastructure | Capacity/rollback/backup hardening; Helm only if justified |
| Security | Staging DAST (allowed env only); container scanning; secrets validation; security release checklist |
| Acceptance | Production readiness review and staging smoke passed |
| Dependencies | Phases 6–9 |
| Не входит | Production cutover |

## Phase 11 — User-created routes

**Цель:** private user routes (draft/active), без публичной модерации.

| Acceptance | Пользователь создаёт и сохраняет private route |
| Dependencies | Phase 8–9 |
| Не входит | Moderation, public listing |

## Phase 12 — Travel+ foundations

**Цель:** Plan/Subscription/EntitlementService config; feature flags; без оплаты.
Включает AI generation limits / model-feature policy (после 8B), без chat UI.

| Acceptance | Free quotas enforced via service; Travel+ flag в dev; AI quotas config |
| Dependencies | Phase 8A (8B optional for AI-specific entitlements) |
| Не входит | Store billing; conversational planner product UI |

## Phase 13 — Trip Planner

**Цель:** Trip / TripDay / TripItem docs→API; attach Route to TripItem.

| Acceptance | Создать поездку и прикрепить route |
| Dependencies | Phase 12 entitlements `trip_planner_enabled` |
| Не входит | Collaborative trips, hotel booking |

## Phase 14 — Traveler progress (ranks, тп, achievements)

**Цель:** заменить mock-блоки профиля (звание, очки «тп», топ, достижения)
данными из backend/БД. Начисление прогресса завязано на реальные события
прохождения маршрутов, а не на клиентский хардкод.

| Область | Задачи |
| --- | --- |
| Docs | data-model + правила начисления тп / рангов / достижений |
| Backend | catalog достижений; прогресс пользователя; ранги; award pipeline |
| Mobile | Profile: rank card, achievements carousel, read API вместо mock |
| API | `/api/v1/me/progress`, `/api/v1/achievements`, `/api/v1/me/achievements` |
| Database | `achievement_definitions`, `user_achievements`, `user_progress` (тп, rank) |
| Events | Начисление из Phase 9 `route_executions` (km, round-trip, complete) |
| Tests | Award invariants; idempotent unlock; ownership; no cross-user leak |
| Security | Только свой progress; catalog публичный read-only; anti-cheat: server-side awards only |
| Acceptance | Профиль показывает звание/тп/достижения с API; mock остаётся только local fallback |
| Dependencies | Phase 6 (user), Phase 9 (execution events); Phase 7 желателен для единого profile |
| Не входит | Социальный шаринг бейджей; PvP; сложные стрики как продукт MVP; магазин за тп |

Правила MVP (preliminary, уточняются в data-model doc фазы):

- **тп** — целочисленные travel points; растут за завершённые executions и
  отдельные achievement unlock (веса в конфиге/seed, не в mobile).
- **Звание** — пороги по тп (например «Продвинутый пешеход»); клиент только
  отображает `rank_title` + `progress/next`.
- **Топ N** — опционально approximate place по тп; допускается отложенный
  пересчёт; не P0-критично для первого merge.
- **Достижения** — seed-каталог (код, title, description, rule_key); unlock
  server-side при matching event; mobile карусель как сейчас в Figma.

Опубликованные маршруты на профиле остаются Phase 11 (user-created +
publication), не часть Phase 14.

## Future — Conversational Route Planner

**Цель:** NL interpretation, clarifying dialogue, `NormalizedRouteRequest`,
iterative edits; тот же `RouteBuilderPipeline`.

| Dependencies | Phase 8B, Phase 12 |
| Не входит | Отдельный chat-only generation engine |

## Future — Self-hosted Tourism AI

**Цель:** Gemma-family inference, RAG, evaluation, optional tuning, provider
migration/canary; optional MCP adapter для тех же tools.

| Dependencies | Phase 8B stable experimental + eval gold set |
| Не входит | Treating model weights as Crimea factual DB |

---

## Backlog

Приоритеты: `P0` (MVP), `P1`, `P2`, `Future`.

| Type | ID | Title | Priority | Repository | Dependency | Acceptance criteria |
| --- | --- | --- | --- | --- | --- | --- |
| EPIC | E-SEC | Security Baseline | P0 | tourism-platform, all | — | docs/security + ADR-007 + skill/CI foundation |
| technical task | SEC-1 | Security docs + threat model | P0 | tourism-platform | — | docs/security present |
| technical task | SEC-2 | Auth ADR-007 | P0 | tourism-platform | SEC-1 | Hybrid Bearer + future cookies chosen |
| technical task | SEC-3 | Security skill/rule/command | P0 | workspace | SEC-1 | Cursor artifacts present |
| technical task | SEC-4 | Backend security tests + pip-audit | P0 | tourism-backend | SEC-1 | tests/security + CI job |
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
| technical task | T5.1 | Shell + theme + secure storage foundation | P0 | tourism-mobile | E5 | Tabs + AppTheme + SecureStorage port |
| technical task | T5.2 | Align layout with flutter-app-architecture.md | P0 | tourism-mobile | T5.1 | core/ + feature presentation/widgets |
| user story | US5.1 | As a traveler I switch main tabs | P0 | tourism-mobile | T5.1 | Bottom nav to Home/Places/Routes/… |
| EPIC | E5.5 | Environment foundation | P0 | tourism-platform, backend, mobile | E5 | Typed env matrix and policy tests |
| technical task | T5.5.1 | Backend/mobile environment contract | P0 | tourism-backend, tourism-mobile | E5.5 | Local/test/staging/production validated |
| technical task | T5.5.2 | Environment-scoped CI configuration | P0 | tourism-platform | E5.5 | No shared secrets or mock data outside local/tests |
| EPIC | E5.6 | First remote test backend | P0 | tourism-platform, tourism-backend | E5.5 | Gamma image test deploy and rollback pass |
| technical task | T5.6.1 | Constrained single-server test stack | P0 | tourism-platform | E5.6 | HTTPS API and private data services healthy |
| technical task | T5.6.2 | Backup and restore smoke | P0 | tourism-platform | T5.6.1 | Encrypted off-host backup restored successfully |
| EPIC | E6 | Authentication | P0 | tourism-backend, tourism-mobile | E2 | Register/login/profile |
| user story | US6.1 | As a user I create an account | P0 | tourism-mobile | E6 | Session persisted securely |
| EPIC | E6.5 | Internal ops admin (SQLAdmin) | P0 | tourism-backend | E6 | Users / OTP / support chat |
| user story | US6.5.1 | As an operator I reply to support from admin | P0 | tourism-backend | E6.5 | Thread visible and reply persisted |
| technical task | T6.5.1 | Admin session auth + CSRF | P0 | tourism-backend | E6.5 | Cookie session, not mobile JWT |
| technical task | T6.5.2 | OTP challenge list (debug_code gated) | P0 | tourism-backend | E6.5 | Test contour only |
| EPIC | E7 | Favorites | P0 | tourism-backend, tourism-mobile | E4, E6 | Save place/route |
| EPIC | E8 | Route builder (8A deterministic) | P0 | tourism-backend, tourism-mobile | E3, E6 | Generate or failure_code |
| technical task | T8.1 | RoutingProvider mock | P0 | tourism-backend | E8 | Swap-ready interface |
| technical task | T8.2 | EntitlementService config free plan | P1 | tourism-backend | E8 | Quotas from config |
| EPIC | E8B | AI-assisted route planning experimental | P1 | tourism-backend | E8 | Flag + mock/Gemini + fallback |
| technical task | AI-ARCH-1 | Provider-neutral AI contracts | P1 | tourism-backend | E8B | Ports without SDK imports |
| technical task | AI-ARCH-2 | NormalizedRouteRequest shared by form and chat | P1 | tourism-backend | E8 | Single DTO |
| technical task | AI-ARCH-3 | Structured output schemas | P1 | tourism-backend | E8B | Interpreted + Proposal |
| technical task | AI-ARCH-4 | ToolRegistry design | P1 | tourism-backend | E8B | Allowlisted tools |
| technical task | AI-ARCH-5 | Gemini adapter | P1 | tourism-backend | AI-ARCH-1 | Env model id |
| technical task | AI-ARCH-6 | AI proposal validator | P0 | tourism-backend | E8B | Candidate allowlist |
| technical task | AI-ARCH-7 | AI repair and deterministic fallback | P0 | tourism-backend | AI-ARCH-6 | Bounded repair |
| technical task | AI-ARCH-8 | Prompt versioning | P1 | tourism-backend | E8B | Version in usage metadata |
| technical task | AI-ARCH-9 | AI observability | P1 | tourism-backend | E8B | AIUsageRecorder |
| technical task | AI-ARCH-10 | Evaluation dataset and runner | P2 | tourism-backend | E8B | Gold set metrics |
| technical task | AI-ARCH-11 | Gemma inference adapter | Future | tourism-backend | AI-ARCH-1 | Self-hosted HTTP |
| technical task | AI-ARCH-12 | Tourism RAG | Future | tourism-backend | AI-ARCH-11 | Docs retrieval |
| technical task | AI-ARCH-13 | Optional MCP adapter | Future | tourism-backend | AI-ARCH-4 | Same tools, MCP transport |
| EPIC | E9 | Route execution | P0 | tourism-backend, tourism-mobile | E4, E6 | Start/complete/history |
| user story | US9.1 | As a traveler I mark visited stops | P0 | tourism-mobile | E9 | Progress updates |
| EPIC | E10 | Production readiness | P1 | tourism-platform, all | E5.6, E6–E9 | Production readiness review |
| EPIC | E11 | User-created private routes | P1 | tourism-backend, tourism-mobile | E8 | Private CRUD |
| EPIC | E12 | Travel+ foundations | P2 | tourism-backend | E8 | Entitlements without billing |
| EPIC | E13 | Trip Planner | Future | tourism-backend, tourism-mobile | E12 | Trip with Route items |
| EPIC | E14 | Traveler progress / achievements | P1 | tourism-backend, tourism-mobile | E6, E9 | Rank + тп + achievements from API |
| user story | US14.1 | As a traveler I see my rank and тп on profile | P1 | tourism-mobile | E14 | Values from `/me/progress`, not mock |
| user story | US14.2 | As a traveler I unlock an achievement after a route | P1 | tourism-backend | E14, E9 | Server awards idempotently on execution complete |
| technical task | T14.1 | Achievement catalog seed + award rules | P1 | tourism-backend | E14 | rule_key mapped to execution events |
| technical task | T14.2 | Replace profile mock progress providers | P1 | tourism-mobile | E14 | Mock only for `DATA_SOURCE=mock` |
| user story | US-F1 | Publish route for moderation | Future | all | E11 | ModerationStatus flow |
| user story | US-F2 | Subscribe to Travel+ | Future | all | E12 | Store purchase |
| user story | US-F3 | Conversational route planner | Future | all | E8B, E12 | NL → NormalizedRouteRequest |
| technical task | T-F1 | Kafka activation | Future | tourism-platform | ADR-005 | Only with real consumers |

### MVP scope (сводка)

P0 epics E0–E9 + необходимые technical tasks. UI — технический Material 3.

### Travel+ scope (будущее)

E12 + billing/store + расширенные quotas/alternatives/offline/export +
conversational planner (US-F3) + AI generation limits.

### AI route planning scope (будущее)

Документ: [ai-route-planning-architecture.md](ai-route-planning-architecture.md),
ADR-006. Реализация: E8B + AI-ARCH-* ; self-host/RAG/MCP — Future.

### Trip Planner scope (будущее)

E13 + collaborative trips + rich TripItem types (accommodation, transport).
