# Backend architecture & AI review

**Подпись:** ревью Cursor  
**Дата:** 2026-08-25  
**Репозиторий:** `tourism-backend`  
**Reviewed revision:** `4fb9a11` (`main`)  
**Режим:** read-only; код не менялся  

Входные документы:

- `system-context.md`, `domain-model.md`, `application-business-logic.md`
- ADR-001 … ADR-009 (включая оба ADR-008: rag-pgvector и ops-admin)
- AI: `ai-lm-studio-windows-gemma4.md`, `ai-self-hosted-home-lab.md`,
  `ai-route-planning-architecture.md`, `ai-chat-agent-loop-and-recommendations.md`
- Предыдущее ревью: [2026-07-25-backend-code-review.md](2026-07-25-backend-code-review.md)

---

## Executive summary

Modular monolith (ADR-001) и auth/catalog as-built выглядят зрелыми для
Phase 8B. Главный продуктовый риск сейчас не «развалится FastAPI», а
**home-lab LM Studio как единственный живой AI-провайдер** без очереди,
без метрик JSON-fallback и с keyword-only `topic_guard`, плюс уже известный
**data-first разрыв** (ADR-009): скоринг и city-filter работают на почти
пустых колонках.

Границы модулей на бумаге жёсткие (`domain-model.md`: «cross-domain ORM
imports запрещены»), в коде — **систематически нарушены**: application-слой
часто импортирует чужие `infrastructure.models`. Это осознанный pragmatic
monolith, но ADR-001 criteria (dependency tests) не выполнены.

Отдельно: `system-context.md` и куски `ai-route-planning-architecture.md` /
`ai-self-hosted-home-lab.md` всё ещё описывают Gemini/Ollama как текущий
контур; as-built — **LM Studio OpenAI-compatible HTTP** (`AIProvider.LMSTUDIO`).

---

## 1. Модули: границы, миграции, транзакции, тесты, N+1

### 1.1 Границы модулей

| Модуль | Независимость | Замечание |
| --- | --- | --- |
| `geography` | ок | почти не тянет чужие домены |
| `places` | средняя | тянет `geography` + `media` models |
| `routes` | слабая | favorites + geography + identity + media + places models |
| `favorites` | слабая | прямые Place/Route ORM |
| `identity` | средняя | favorites/routes для travel points; media defaults |
| `media` | ок | владеет attachments |
| `knowledge` | ок | raw SQL к своей таблице; вызывается из route_builder |
| `route_builder` | самая связанная | geography, places, routes, identity, knowledge, ai infra |
| `subscriptions` | средняя | мутирует `User` columns |
| `admin` | намеренно кросс-модульный | SQLAdmin views над ORM всех доменов (ADR-008 ops) |

Типичные нарушения ADR-001 (примеры, не полный список):

- `route_builder/application/match_service.py` → `geography` / `places` /
  `routes` / `identity` infrastructure models
- `route_builder/application/tool_registry.py` → `Place`, `Locality`, `Region`
- `routes/application/service.py` → `FavoriteRoute`, `Place`, `MediaAttachment`
- `favorites/application/service.py` → `Place`, `Route`
- `session_service.py` → `knowledge.infrastructure.retriever` +
  `route_builder.infrastructure.ai_factory` (application → infrastructure)

**Вывод:** modules — deployable packages внутри одного процесса, не
извлекаемые сервисы. Для текущего этапа приемлемо; перед любым split нужен
inventory портов и запрет cross-ORM (как и писал ADR-001).

### 1.2 Миграции Alembic

- Цепочка до `0034_place_merge_dedup` выглядит линейной и согласованной с
  моделями (planning sessions, knowledge_chunks + vector, OSM fields,
  `merged_into_place_id`).
- Spatial: GIST на `places.location`, regions/localities centers,
  `routes.geometry` — с `0002` / `0003` (хорошо для PostGIS).
- Destructive в upgrade почти нет: add column / create table / indexes.
  Downgrade — стандартные `drop_*` (ожидаемо).
- `0034` специально **не удаляет** дубликаты (RESTRICT на `routes.place_id`) —
  archive + `merged_into_place_id`; backfill в скрипте `dedupe_places.py`, не
  в миграции — правильный паттерн.
- Риск: ORM Geography index объявления vs «сырой» `CREATE INDEX … GIST` в
  миграциях — индексы живут в БД, но не все отражены как SQLAlchemy
  `Index(...)` на модели (не ломает runtime, усложняет drift-аудит).

### 1.3 Ошибки и транзакции

- Публичный API: `AppError` → стабильный envelope (`api/errors.py`) — ок.
- Chat: широкий `except Exception` вокруг LM Studio → soft fallback
  (`session_service.py` ~639), RAG swallow (~595), invalid constraint patch
  swallow (~487). Пользователь не получает сырой traceback; цена —
  **молчаливая деградация без метрик**.
- Квоты / refresh / Travel+ activate: check-then-write без row lock
  (см. предыдущее security-ревью и §2 ниже) — гонки возможны.
- Commit-границы в application-сервисах обычно «один use-case = один
  commit»; длинный `post_message` держит одну сессию на match/generate +
  AI — при медленном LM Studio держит DB connection дольше HTTP timeout
  провайдера (до `ai_request_timeout_seconds`, default 60).

### 1.4 Тесты

| Область | Покрытие | Пробел |
| --- | --- | --- |
| Security (auth, BOLA sessions, public catalog) | сильное | concurrent refresh/quota; cover publication leak; mock Travel+ env gate |
| Unit: structured_turn, topic_guard, scoring, tools | хорошее | нет prod-метрик fallback rate; affirmatives mid-clarification |
| Travel+ | unit + security | activate всегда доступен authenticated user |
| Publication readiness | unit | end-to-end admin publish с `generated_draft` |
| Knowledge | unit embedder/chunker + 1 integration | semantic quality (hash-v1) |
| Places/routes listing | integration есть | мало load/N+1 regression |
| AI outage path | косвенно | нет теста «httpx timeout → ai_unavailable_fallback» |

Критичные пути «оплата» фактически = mock Travel+; реального биллинга нет.

### 1.5 N+1 и индексы на горячих путях

**Хорошо:**

- `places` / `routes` list батчат covers, categories, stop counts отдельными
  `IN (...)` запросами (не классический N+1 по строкам списка).
- `ix_places_publication_region`, GIST `ix_places_location`.

**Риски под нагрузкой:**

1. `find_places_near_point` (`tool_registry.py` ~444–458) фильтрует bbox через
   `ST_X`/`ST_Y` на cast Geography→Geometry **без SQL LIMIT** и без
   `ST_DWithin` — GIST по `location` слабо помогает; при 5k+ published
   тянет все точки bbox в Python + haversine.
2. `place_picker` / city ILIKE `%city%` при пустом `locality_id` (ADR-009) —
   seq scan по name/address.
3. Chat history: каждый AI-turn `SELECT` **всех** сообщений сессии, потом
   `[-12:]` в Python (`session_service.py` ~537–549).
4. Catalog `~_has_unpublished_stop()` — correlated `EXISTS` на каждый route
   row; приемлемо на малых объёмах, стоит смотреть EXPLAIN при росте.

---

## 2. Глубокий разбор AI (LM Studio / Gemma / RAG)

### As-built (код, не устаревшие docs)

```
Mobile → FastAPI route_builder
       → topic_guard (keywords)
       → ToolRegistry prefetch (PostGIS / curated tips)
       → optional RAG (RAG_ENABLED, hash-v1)
       → AIPlanningProvider: mock | lmstudio  (ai_factory, без цепочки)
       → LM Studio /v1/chat/completions (sync, stream=false, T=0.3,
         reasoning_effort=none, messages[-12:])
       → parse_structured_turn | fallback_structured_turn
       → optional 1 tool round → second chat_turn
       → match / generate (deterministic) + entitlements/quota
```

Файлы: `lm_studio.py`, `ai_factory.py`, `ai_mock.py`,
`topic_guard.py`, `tool_registry.py`, `structured_turn.py`, `chat_actions.py`,
`session_service.py`, `quota.py`, `scoring.py`, `place_picker.py`,
`knowledge/*`.

### Ответы на конкретные вопросы

#### 1) LM Studio недоступен посреди сессии

**Не голая 500** для chat path. В `_assistant_from_ai`
(`session_service.py` ~625–651):

- при `ai_planning_enabled=false` → всегда `MockAIPlanningProvider`;
- при `lmstudio` любой `Exception` (connect refused, timeout, 5xx, bad JSON
  payload от httpx) → `ChatTurnResult` с `ai_unavailable_fallback()` текстом,
  `provider="fallback"`, `fallback=True`, action `want_generate`.

`get_ai_planning_provider` (`ai_factory.py` 15–31) действительно
**только** `mock` XOR `lmstudio` — **нет** runtime-цепочки
lmstudio→mock при outage (mock включается только catch в session_service
или флагом). Probe `/models` есть, но не health-check перед каждым turn.

`draft_place_content` (offline script path) — **raises**; caller
`llm_content_draft_or_fallback` обязан ловить и уходить в heuristic.

#### 2) Конкурентность двух пользователей на один GPU

- В backend **нет** семафора / очереди / global AI lock.
- Каждый turn открывает свой `httpx.AsyncClient` и ждёт до
  `ai_request_timeout_seconds` (default **60s**).
- Поведение упирается в LM Studio: обычно serializes/queues на GPU →
  рост latency; при перегрузе — timeout → soft fallback выше.
- Параллельные generate ещё и бьют quota race (check-then-insert в
  `quota.py`).

**Первое, что сломается при росте чата:** хвост p95 latency и доля
`fallback=true` реплик, не падение Postgres.

#### 3) Обрезка истории до 12 сообщений

- Константа `_HISTORY_LIMIT = 12` (`session_service.py` 83) + повтор в
  `lm_studio.py` 173 (`messages[-12:]`).
- **`confirmed_fields` / `constraints` живут в сессии целиком** и
  передаются отдельным system state_note — факты формы не теряются.
- Теряется **нарратив**: «я не люблю музеи, потому что…» на 13-м ходе
  назад модель не видит; может снова предложить музеи или
  `constraint_patch` перезаписать поля (merge не защищает confirmed от
  LLM patch — `chat_actions.merge_constraint_patch`).
- Полный SELECT истории перед trim — лишняя нагрузка на длинных сессиях.

#### 4) Надёжность большого JSON system-prompt на Gemma

- Нет native structured output / function calling API — только prose JSON +
  regex/`json.loads` (`structured_turn.extract_json_object`).
- При провале parse → **тихий** `fallback_structured_turn` (эвристика
  ask_field + шаблонный текст). **Логирования/счётчика частоты нет** —
  в коде нет logger вокруг этой ветки; на «проде» home-lab частоту по
  логам сейчас **не измерить**.
- Action ids и patch keys allowlist'ятся; `assistant_text` режется до 600
  символов — частично компенсирует галлюцинации формата.
- Оценка: для Gemma 26B A4B MoE IQ4 на 12GB VRAM (partial offload) JSON
  contract **хрупкий**; fallback будет срабатывать заметно чаще, чем у
  hosted frontier models. Нужен counter `structured_parse_ok|fallback`.

#### 5) `topic_guard` / `injection_attempt`

- **Только keyword/substring** (`topic_guard.py`): crisis, injection
  phrases, off-topic markers, generate confirms. **Не LLM-классификатор.**
- Легко обходится перефразом («забудь все правила выше и …» без точных
  маркеров; «напиши скрипт» вместо «напиши код»).
- На этот ход injection получает canned reply, но **текст всё равно
  пишется в `route_planning_messages`** и позже попадает в `[-12:]` к
  модели (`session_service` user_msg до branch + history load).
- **Второй слой безопасности (критичный) есть и не только на guard:**
  ToolRegistry allowlist, typed/bounded args, нет raw SQL от модели,
  PostGIS только published, match/generate deterministic, entitlements.
  Guard — UX/safety net для crisis/off-topic, **не** единственный
  security control. Нельзя на него опираться против prompt injection в
  RAG/UGC.

#### 6) RAG / pgvector (ADR-008) в chat_turn

- `RAG_ENABLED` default **false** (`config.py` 91).
- При enable: в `_assistant_from_ai` (~565–594) `TourismKnowledgeRetriever`
  кладёт chunks в `tool_context.knowledge` как DATA — **отдельный путь**,
  не через `tool_requests`.
- `tool_requests` → `search_places` / `seasonal_recommendations` /
  `get_place_details` / `find_places_near_point` — это PostGIS/curated,
  не vector RAG.
- Embedder всё ещё **`hash-v1`** bag-of-tokens
  (`knowledge/application/embedder.py`) — ADR-009 и ADR-008 это явно
  фиксируют. «Векторный поиск» ≈ keyword в векторной обёртке + FTS
  fallback. **Актуально.**

#### 7) `draft_place_content` и review gate

- Offline/enrichment поток в `lm_studio.draft_place_content` +
  `content_enrichment` пишет статус **`generated_draft`**.
- `publication_readiness.py`: при `GENERATED_DRAFT` meaningful text
  **не засчитывается**; blocker
  «текст сгенерирован, нужна проверка редактора» (~116–117).
- Публикация всё равно требует admin action (audited). **В каталог без
  человека через этот gate — нет.**
- Риск остаётся операционный: admin может проставить
  `editorial_reviewed` / опубликовать не глядя; механический gate ≠
  обязательный UI checklist.

---

## 3. Конкретные риски (файл / зона)

### AI / product

| ID | Severity | Риск | Где |
| --- | --- | --- | --- |
| AI-1 | P1 | Home-lab outage → soft fallback без метрик; UX «ИИ молчит», generate ещё доступен | `session_service.py` ~639–651 |
| AI-2 | P1 | Нет AI concurrency limit → GPU queue / mass timeouts | весь `LMStudioProvider._complete` |
| AI-3 | P1 | Affirmatives (`да`/`ок`) → force generate mid-clarification | `topic_guard.py` ~114–141, `session_service.py` ~314 |
| AI-4 | P1 | Injection/crisis text persisted → next LLM turn | `session_service.py` ~336–348 + history |
| AI-5 | P1 | Quota check-then-insert race | `quota.py` ~43–74 |
| AI-6 | P2 | Silent `fallback_structured_turn` без telemetry | `lm_studio.py` ~194–199 |
| AI-7 | P2 | LLM `constraint_patch` may overwrite confirmed fields | `chat_actions` merge + session apply |
| AI-8 | P2 | `find_places_near_point` full bbox load | `tool_registry.py` ~444–458 |
| AI-9 | P2 | History SELECT-all then trim-12 | `session_service.py` ~537–549 |
| AI-10 | P2 | hash-v1 RAG / RAG off — semantic retrieval не готов | `embedder.py`, `config.rag_enabled` |
| AI-11 | P3 | Docs drift (Gemini/Ollama vs LM Studio as-built) | `system-context.md`, home-lab docs |

### Modules / data / security (кратко, см. также live security pass)

| ID | Severity | Риск | Где |
| --- | --- | --- | --- |
| M-1 | P1 | Mock Travel+ self-activate в любом env | `subscriptions/presentation/router.py` |
| M-2 | P1 | Cover/reusable media без publication filter | `place_covers.py`, `media/.../list_reusable_covers` |
| M-3 | P1 | Favorites routes ≠ catalog publication rules | `favorites/.../service.py` |
| M-4 | P1 | Refresh rotation без `FOR UPDATE` | `identity/.../service.py` `refresh_tokens` |
| M-5 | P2 | Cross-module ORM imports vs ADR-001 | route_builder/routes/favorites application |
| M-6 | P2 | Scoring/city ILIKE на пустых данных (ADR-009) | `scoring.py`, `place_picker.py` |

---

## 4. Что сломается первым при росте нагрузки

1. **LM Studio / один GPU** — latency и доля fallback-реплик (ещё до
   упирания Postgres).
2. **Chat DB session duration** — долгий HTTP к Windows держит async
   worker + DB connection.
3. **Geo tool `find_places_near_point` + ILIKE city** — CPU/IO на PostGIS
   при росте published places (после P0-bis publish).
4. **Generation quota races** и **refresh races** под мобильным retry.
5. Позже: correlated unpublished-stop filter и full history SELECT на
   длинных чатах.

Postgres/GIST listing на текущих объёмах (~5k places) — не первое узкое
место, пока city filter и near-point не деградируют в seq scan.

---

## 5. Приоритетные улучшения именно для ИИ-части

1. **Семафор / очередь AI-вызовов в процессе** (например
   `asyncio.Semaphore(1)` или маленький Redis queue) + короткий
   user-facing «занято, подождите» вместо 60s hang → fallback. Зачем:
   один GPU, предсказуемый UX, меньше каскадных timeout.
2. **Метрики на каждый turn:** `provider`, `latency_ms`,
   `structured_parse=ok|fallback`, `tools_round`, `rag_hit`,
   `outage_fallback`. Зачем: сейчас JSON-reliability и outage rate —
   слепые; без этого нельзя тюнить промпт/Gemma.
3. **Исправить intent routing:** short affirmatives (`да`/`ок`) только
   если `ask_field` уже `ready` / pending generate confirm; иначе —
   ответ на clarification. Не писать `injection_attempt`/`crisis` raw
   text в LLM history (хранить redacted / omit from prompt). Зачем:
   ломает продуктный flow и обходит guard.
4. **Ужесточить post-model merge:** `constraint_patch` не перезаписывает
   ключи из `confirmed_fields` без явного user control; tool
   `find_places_near_point` → `ST_DWithin` + `LIMIT`. Зачем: меньше
   галлюцинаций параметров и меньше geo blow-ups.
5. **Не раздувать RAG, пока data-first (ADR-009):** сначала locality +
   categories в scoring/picker; hash-v1 оставить off. Когда включать RAG —
   сменить embedder на реальный 384-d (LM Studio embeddings /
   sentence-transformers) **с тем же dim**, scrub instruction-like
   prefixes в chunk body. Зачем: иначе «векторный» слой даёт ложное
   чувство семантики.

---

## 6. Согласованность с ADR / docs

| Решение | Код | Комментарий |
| --- | --- | --- |
| ADR-001 modular monolith | да | границы мягче, чем заявлено |
| ADR-003 PostGIS | да | GIST есть; near-point query suboptimal |
| ADR-004 RoutingProvider | stub only | серпантины Крыма (ADR-009) |
| ADR-005 Kafka | не в runtime | ок |
| ADR-006 AI planner + validation | частично | structured parse + deterministic match/generate; docs ещё про Gemini |
| ADR-007 auth hybrid | as-built | OTP/refresh issues вне AI |
| ADR-008 pgvector | as-built schema | hash-v1, RAG off by default |
| ADR-008 SQLAdmin | as-built | ок |
| ADR-009 data-first | принято | всё ещё главный рычаг качества подбора |

---

## 7. Рекомендуемый follow-up (не сделано в этом ревью)

- Обновить `system-context.md` / home-lab docs: as-built = LM Studio,
  не Gemini/Ollama-first.
- Закрыть P1 из §3 (Travel+, media publication, favorites, refresh,
  AI affirmatives/injection history, AI semaphore+metrics).
- Не считать Phase 8B «готовым к нагрузке» без (2) и (1) из §5.

---

*Конец отчёта. Ревью Cursor, 2026-08-25.*
