# Оценка готовности плана реализации — 2026-08-28

Статус: **актуальный инженерный аудит и вход в детальное планирование**.

Этот документ отвечает на три вопроса:

1. Насколько текущие планы соответствуют фактическому коду и ограничениям
   внешних провайдеров.
2. Что уже достаточно хорошо для начала реализации.
3. Что необходимо уточнить, чтобы команда могла выполнять работу без
   догадок, скрытых зависимостей и опасных обещаний пользователю.

Это не сертификат соответствия стандартам и не независимый penetration test.
Оценка сделана по состоянию workspace на 2026-08-28 и должна обновляться при
изменении контракта или архитектурного решения.

## Итоговый вердикт

План уже **выше среднего для живого test-contour проекта**: есть modular
monolith, ADR, typed API schemas, миграции Alembic, security baseline,
отдельные документы по данным, маршрутизации, рекомендациям и deployment.
Начинать реализацию можно.

Однако до появления этого аудита план был распределён по нескольким файлам и
местами описывал желаемое состояние как уже готовое. Для сложной связки
«маршрут → 2ГИС → карта → прохождение → рекомендации» это создавало четыре
риска:

- разработчик мог выбрать несовместимую версию/тип ключа 2ГИС;
- mobile мог начать отображать synthetic geometry как настоящую;
- рекомендации могли превратиться в filter bubble;
- route execution и rewards могли разойтись по разным определениям
  «маршрут завершён».

После добавления [implementation blueprint](implementation-blueprint-2026-08.md)
документация считается пригодной как executable-план: у каждой крупной части
есть владелец, входы, выходы, зависимости, ошибки, тесты и Definition of Done.

### Delta после первого implementation slice (28.08.2026)

После первоначальной оценки реализован безопасный первый срез, который нужно
учитывать при чтении таблиц ниже:

- backend: `TwoGisRoutingProvider` (HTTP, walking/driving, detailed geometry,
  typed errors, indexed-response normalization, cm→m altitude conversion) и
  bounded profile-preference scoring;
- mobile: API-only personalization prompt, расширенный quiz, L1 read-only
  offline route snapshots/list/clear и logout cleanup;
- provider-result quality gate v1 и RouteDetail GeoJSON/time/altitude/quality
  DTO уже добавлены; mobile использует geometry и объясняет quality status;
- остаются release-blocking: реальный key smoke, retention scheduling/alerts,
  независимая проверка полного terrain/water/access контура, Active
  Route/resume/outbox, recommendation deck/
  feedback, catalog dry-run и native SDK/handoff/widgets. Application-level
  append-only snapshots, DB trigger mutation guard и stop-data gate v1 уже
  добавлены.

Актуальный breakdown и статусы находятся в [progress.md](progress.md) и
[расширенном плане](2gis-personalization-offline-plan-2026-08-28.md). Ниже
сохранён исторический baseline первичного среза; он не должен использоваться
как текущий статус без сверки с `progress.md`.

## Оценка зрелости

Шкала: 1 — идея, 3 — описанный прототип, 5 — можно реализовывать без
архитектурных догадок, 7 — проверенный production-процесс, 10 — зрелая
эксплуатационная система. Баллы не означают сертификацию.

| Область | Сейчас | Целевой уровень до production rollout | Комментарий |
| --- | ---: | ---: | --- |
| Архитектура и границы модулей | 7/10 | 8/10 | Modular monolith и ports/adapters уже есть; нужно закрепить routing/recommendation contracts |
| Backend foundation | 7/10 | 8/10 | Auth, миграции, typed schemas и route-execution v0 работают |
| Route execution | 4/10 | 8/10 | API есть, mobile journey, resume/offline и rewards ещё впереди |
| Дорожная реалистичность | 6/10 | 8/10 | HTTP adapter, provider-result/stop-data/region-road-event gate v1 и immutable execution snapshots есть; полноценные terrain/access checks и real smoke ещё впереди |
| 2ГИС integration readiness | 6/10 | 8/10 | HTTP adapter, quota guards, contract tests и key separation есть; real-key smoke, vendor confirmation и mobile SDK остаются |
| Данные каталога | 5/10 | 8/10 | Есть publish gate и импорт, но районность, freshness и trail metadata неполны |
| Recommendations | 3/10 | 8/10 | Хорошая концептуальная записка, backend deck/feedback пока не реализованы |
| Использование preferences | 5/10 | 8/10 | Профильные сигналы уже участвуют в match/generate как мягкий prior; feedback/decay/diversity ещё впереди |
| Mobile UX | 6/10 | 8/10 | Сильный shell и visual system; route map/execution states отсутствуют |
| Security/privacy | 6/10 | 8/10 | Baseline и security tests есть; точная геолокация, vendor keys и admin gaps требуют закрытия |
| Наблюдаемость и operations | 5/10 | 8/10 | Deploy/health/runbook есть, продуктовые SLO, quota alerts и trace correlation нужно добавить |
| API/documentation governance | 5/10 | 8/10 | OpenAPI генерируется, но нет стабильного snapshot/compatibility gate и единого source of truth |

**Общая готовность плана:** примерно **6/10** до blueprint и **8/10** после
его принятия. **Готовность продукта к обещанию «безопасно провести туриста по
маршруту» сейчас ниже — около 4/10**, пока не появятся реальная geometry,
quality gate и mobile execution.

## Что уже сделано хорошо

### Архитектура

- Модульный монолит выбран разумно для текущего масштаба.
- `RoutingProvider` — правильная точка расширения; провайдер не должен
  протекать в application layer.
- Backend использует явные Pydantic response models, а mobile — repository
  abstractions и Riverpod.
- Миграции и security regression tests находятся рядом с кодом.
- Решение не тащить Kafka/Kubernetes/LLM/RAG до появления качественных данных
  экономит время и снижает operational risk.

### Документация

- Есть ADR-ы по модульному монолиту, PostGIS, auth, admin, AI и data-first
  стратегии.
- Есть отдельные документы для route intelligence, swipe deck, deployment,
  security и mobile architecture.
- Документы уже фиксируют важное ограничение: synthetic distance нельзя
  выдавать за дорожное расстояние.

### Безопасность

- Есть целевой baseline OWASP ASVS Level 2 для API и MASVS baseline для
  mobile.
- Есть классификация данных и запрет отправлять точную геолокацию в
  сторонние/AI-сервисы без необходимости.
- API-ключ 2ГИС уже находится в `.env` и не отслеживается Git.

## Главные несоответствия, которые нельзя оставить

### 1. Demo key 2ГИС не равен Mobile SDK key

По документации 2ГИС бесплатный demo key действует один месяц и предназначен
для HTTP API. Demo keys не работают с Mobile SDK. Для SDK нужна отдельная
subscription key; ключ с App ID предназначен только для SDK и не может
использоваться для прямых HTTP-запросов. Поэтому план обязан разделять:

- `TWO_GIS_HTTP_API_KEY` — backend HTTP Routing API (legacy deployment
  aliases принимаются только на период миграции);
- отдельные iOS/Android/Flutter SDK keys — только после решения по лицензии и
  подписке.

Нельзя переиспользовать backend key в мобильном бинарнике или считать, что
полученный demo key автоматически даёт право встраивать карту в приложение.

### 2. 2ГИС подтверждает путь по своему графу, но не гарантирует безопасность похода

Routing API умеет режимы движения, фильтры дорог, зоны исключения,
высотность, duration и статусы невозможности построения. При этом документация
предупреждает, что исключённые типы дорог могут всё же попасть в результат,
если без них маршрут невозможно построить. Кроме того, наличие тропы в графе
не означает, что она безопасна, открыта сегодня или подходит ребёнку.

Нужны два уровня проверки:

1. техническая проверка ответа провайдера;
2. собственный editorial/safety gate с источниками, freshness, terrain и
   ручным review для рискованных маршрутов.

### 3. Профиль preferences пока хранится, но не персонализирует выдачу

Текущие поля — `preferred_categories` (до четырёх),
`preferred_difficulty`, `travels_with_kids`, `travels_with_pets`.
Они должны быть отдельным явным prior. Просмотр карточки — слабый сигнал;
favorite, start и completion — более сильные. Один просмотр двух горных
маршрутов не должен менять профиль и запирать пользователя в категории
«Горы».

### 4. Route execution определён на backend, но пользовательский цикл ещё не замкнут

`RouteExecution` уже хранит snapshot остановок и state machine
active/completed/cancelled. Однако mobile пока должен получить карту,
progress, resume, понятные ошибки, ручное подтверждение в v0 и историю.
Rewards нельзя начислять просто за нажатие «Завершить» без согласованного
правила подтверждения.

### 5. Документы не всегда синхронны со статусами

Исторические review-файлы намеренно сохраняются неизменными, но живые планы
должны ссылаться на один статусный источник. В blueprint введена иерархия:

1. фактический код и green validation;
2. `docs/progress.md`;
3. blueprint и implementation plan;
4. специализированные design/route/security docs;
5. исторические review-документы.

Если текст конфликтует с кодом, нельзя молча выбирать удобную версию — нужно
добавить запись в changelog и обновить canonical doc.

## Проверка против инженерных стандартов

| Практика | Оценка | Что требуется |
| --- | --- | --- |
| OWASP ASVS 5 / Level 2 | Частичное соответствие | Вести control matrix с evidence; отдельно закрыть admin, media, rate limits, secrets и vendor callbacks |
| OWASP MASVS / MASTG | Частичное соответствие | Проверить secure storage, TLS, screenshots/logging, SDK key restrictions, permission UX на реальных сборках |
| OpenAPI 3.1 governance | Частичное соответствие | Зафиксировать snapshot, backward-compatibility diff и generated mobile contract fixtures |
| RFC 9457 Problem Details | Требует унификации | Привести provider/quality/availability errors к machine-readable `type`, `status`, `code`, `trace_id`, `details` |
| ADR / Architecture Decision Records | Хорошо | Добавить ADR-010 по 2ГИС и ADR-011 по personalization/safety semantics |
| Twelve-Factor / secret hygiene | Хорошо, но проверить rollout | Раздельные env/secrets для HTTP и SDK; rotation и quota alert без ключей в логах |
| Test pyramid | Частичное | Добавить contract, property, resilience, device smoke и data-quality fixtures |
| SRE/operations | Частичное | Определить SLO, error budget, dashboards, alert ownership и rollback playbook |
| Accessibility | Частичное | Семантика карт/кнопок, dynamic type, reduced motion, contrast, screen-reader route progress |
| Privacy by design | Хорошая база | Отдельное consent/retention решение для optional GPS; explainable personalization и reset |

Рекомендуемый security baseline опирается на [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
и [OWASP MASVS](https://mas.owasp.org/MASVS/). Для API-ошибок следует
ориентироваться на [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html),
а схему контрактов вести в соответствии с [OpenAPI Specification](https://spec.openapis.org/oas/).

## Что изменено blueprint-документом

Новый blueprint добавляет отсутствующие связки:

- пользовательские сценарии и обещания продукта;
- словарь route semantics: movement/visit/buffer/total time;
- единую taxonomy difficulty/accessibility/availability;
- входы и выходы 2ГИС adapter;
- hard/soft safety constraints и quality statuses;
- recommendation signals, caps, decay, diversity, exploration и reset;
- state machine route execution и manual-v0 semantics;
- API compatibility, idempotency и error contract;
- migration strategy expand → backfill → switch → cleanup;
- test matrix от unit до device/manual field smoke;
- metrics, SLO, quota/budget alerts и rollback;
- risk register, decision deadlines и traceability matrix.

## Критерий «план можно отдавать агенту»

Агент или разработчик может взять одну карточку работ только если в ней
указаны:

- уникальный ID и приоритет;
- конкретный repository/module/file area;
- входной контракт и ожидаемый output;
- hard constraints и privacy/security requirements;
- migration/backward-compatibility impact;
- unit/integration/contract tests;
- observability event/metric;
- rollback или безопасный feature-flag path;
- Definition of Done и ручной smoke сценарий.

В blueprint каждая следующая workstream-карточка построена по этой форме.

## Решение по продолжению

Можно начинать реализацию, но в таком порядке:

1. **B0 — contract/ADR:** зафиксировать 2ГИС key separation и route quality
   schema.
2. **B1 — backend adapter:** HTTP Routing API в test contour, без mobile SDK.
3. **B2 — safety/data gate:** geometry, terrain, access, availability,
   quality statuses.
4. **B3 — route execution mobile:** карта и прохождение на проверенном
   snapshot.
5. **B4 — recommendation backend:** preferences + bounded behavior +
   diversity.
6. **B5 — recommendation mobile:** deck, feedback, explanations and reset.
7. **B6 — rewards/production hardening:** only after verified completion and
   metrics.

2ГИС не блокирует текущий route-execution API v0: до появления real geometry
он может работать в тестовом режиме с честным обозначением ограничений. Но
публиковать маршрут как готовый к безопасному прохождению без quality gate
нельзя.
