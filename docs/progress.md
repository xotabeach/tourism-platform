# Progress log

Живой статус разработки. Детальный план фаз —
[implementation-plan.md](implementation-plan.md). После завершения фазы
обновляй этот файл: статус, что сделано, что дальше, блокеры.

**Текущая фаза:** Phase 8B (AI chat sessions + LM Studio planning) — in progress.

**Стратегия подбора пересмотрена 2026-08-23:** замер данных показал, что
узкое место не в AI-слое, а в заполненности `places`. Решение —
[ADR-009](decisions/ADR-009-data-first-route-intelligence.md), план по
фазам — [route-intelligence-roadmap.md](route-intelligence-roadmap.md).

**P0 «Данные» — выполнено и раскатано 2026-08-23.** Детали и цифры в
[роадмапе](route-intelligence-roadmap.md).

**Next (завтра) — P0-bis, детали и цифры в
[роадмапе](route-intelligence-roadmap.md) §P0-bis:**

1. **Дедупликация seed ↔ OSM** — блокер публикации. У 16 из 20 seed-мест
   есть OSM-двойник в 400 м; из-за этого «Ханский дворец» показывается
   без фото (фото досталось OSM-копии, а видна seed-копия). Публиковать
   OSM-места без слияния нельзя — будут видимые дубли.
2. **Описания.** Seed-места: `description` заполнен у 3 из 20, есть лишь
   `short_description` медианой 42 символа — это и есть «супер короткие
   описания» в приложении. Лучший источник для OSM-мест —
   **Wikipedia extracts** (278 мест с тегом `wikipedia`/`wikidata` и без
   текста; CC BY-SA, без токена, тот же QID, что уже используется для
   фото). LLM — только на остаток и только через review.
3. **Районы для 700 мест без города.** `Locality.boundary`
   (MULTIPOLYGON) и `parent_locality_id` в схеме уже есть — импортировать
   границы OSM `admin_level=6` и привязывать через `ST_Within`
   (point-in-polygon) вместо радиуса 25 км.
2. **P1 — семантика:** заменить `hash-v1` (bag-of-tokens хеш, не
   семантика) на настоящий эмбеддер, распространить вектора на
   `places` / `routes`, гибридный retrieve.
3. **P2 — OSRM:** сейчас маршрут это прямая × 1.35; для серпантинов
   Крыма расхождение кратное.
4. **CI-минуты:** дать `tourism-mobile` / `tourism-platform` /
   `workspace` такие же `web`-only `workflow.rules`, как у backend —
   сейчас пуш в `main` там создаёт пайплайн. До этого пушить с
   `-o ci.skip` (см. [ci-and-runners.md](ci-and-runners.md)).

**Дальше (P3–P4, детали в роадмапе):** погодное переранжирование
(Open-Meteo), парсер `opening_hours_raw`, высотный профиль, золотой час,
многодневная структура, обучение на accept/reject.

**Отложено (решение принято, реализация позже):**

- **Точка входа «Новый чат»** → отдельный экран истории чатов, вход из
  настроек (вариант 3). Код `_startNewChat` / `onNewChat` не удалять.
- **Карточка-ответ «расскажи о месте»** — план в
  [ai-route-chat-mobile-implementation.md](ai-route-chat-mobile-implementation.md).
- Mapillary как второй источник фото (нужен свой API token).
- Review gate для `proposed_slug` / photo `is_cover` перед публикацией.

**Последнее обновление:** 2026-08-23

## Changelog

### 2026-08-24 — Review-gate публикации мест + PlaceAdmin

- Механический гейт `publication_readiness.py` (чистый, оттестирован):
  блокеры (нет города / категории / содержательного текста / закрыто)
  отделены от предупреждений (нет своего фото — есть fallback).
  Машинный текст (`generated_draft`) намеренно не считается содержанием.
- `PlaceAdmin` — вьюхи для `Place` в админке не было вообще. Действия
  «Опубликовать» / «Отклонить» / «Вернуть в черновики» с audit-логом;
  `publication_status` вне `form_columns`, поэтому статус меняется только
  через них. Публикация перепроверяет гейт и **fails closed**, записывая
  `admin.place_publish_blocked` с причинами.
- `scripts/place_publication_report.py` — read-only триаж; публиковать
  не умеет (нужен admin-принципал в audit-логе).
- **Замер:** готовы 141 место, 4824 блокирует отсутствие описания, 700 —
  отсутствие города, 13 — непригодное название. Медиана длины
  OSM-`description` = 9 символов (маркеры «МК-29»), поэтому 786 непустых
  дают лишь 141 пригодное. Вывод: настоящий блокер — контент, а не гейт.
- Проверка вывода гейта на реальных данных нашла его же пробел: родник с
  именем «(плохая вода)» проходил, т.к. описание у него настоящее.
  Название теперь проверяется на пригодность (не только на непустоту).
- **CI-минуты:** выяснилось, что пуш в `main` создаёт пайплайн в
  `tourism-mobile`, `tourism-platform` и `workspace` (у последнего вообще
  нет `workflow:` правил) — только backend отключён полностью.
  Задокументировано в [ci-and-runners.md](ci-and-runners.md), до
  исправления правил пушим с `-o ci.skip`.

### 2026-08-23 — P0 «Данные» выполнено (ADR-009)

- **Локальности:** `backfill_place_localities.py` — привязка к ближайшему
  центру локальности через PostGIS, места дальше 25 км осознанно остаются
  `NULL` (лучше без города, чем с неверным). **1.7% → 86.1%.** Досеяны
  «Саки» и «Керчь», которых чат предлагал, а в БД не было (8 → 10);
  добавлен режим `seed_crimea.py --localities-only`.
  Контрольная проверка: две одноимённые «Генуэзские крепости» корректно
  разошлись по Судаку и Феодосии — чего подстрочный матчинг не мог.
- **Таксономия в скоринг:** `INTEREST_CATEGORIES` / `TRIP_TYPE_CATEGORIES`
  в `scoring.py`, слаги категорий проброшены в `RouteMatchCandidate` и
  `place_picker`. Категории проверяются первыми, ключевые слова остались
  fallback-ом. Вес города (0.32) по-прежнему доминирует — таксономия не
  вытягивает маршрут в чужом городе (покрыто тестом).
- **Промоут тегов OSM:** миграция `0033` (`elevation_meters`,
  `opening_hours_raw`, `surface`) + `promote_osm_fields.py`.
  `description` 0.1% → 15.7%, `elevation_meters` 15.4%,
  `recommended_visit_minutes` 0% → 99.6%. Маппинг — чистый
  оттестированный модуль: `website` принимает только http(s) (в OSM в
  этом теге встречаются голые хосты и мусор), `ele` проверяется по
  диапазону.
- `_estimate_duration` учитывал время осмотра и раньше, но при пустой
  колонке применял плоские 45 мин к каждой точке; теперь оценка
  категорийная (памятник 20, тропа 150).
- **Известный блокер:** импортированные места остаются `draft`,
  `place_picker` отбирает только `published` → генерация всё ещё видит
  20 seed-мест. Нужен review-gate.
- **Флейки-тест:** `test_route_reviews_notifications_security.py::
  test_delete_own_review_within_window_and_rejects_foreign` упал 1 раз из
  4 полных прогонов, в изоляции и при повторе стабильно зелёный.

### 2026-08-23 — Замер данных, ADR-009 data-first, реальный импорт на прод

- **Замер заполненности `places` на test-контуре** вскрыл, что потолок
  подбора — данные, а не AI: `locality_id` 1.7%, `recommended_visit_minutes`
  / `access_transport` / `price_*` 0%, `typical_crowding` 100% `unknown`,
  `description` 3 места из 5020. Пять из восьми компонентов `scoring.py`
  читают эти колонки и всегда отдают нейтральный дефолт 0.4–0.5.
- **Главная находка:** `place_categories` заполнены у **100%** мест
  (15 категорий), но `scoring.py` и `place_picker.py` их не используют —
  ищут подстроку «гор» по свободному тексту с заполненностью 0.1%.
- Зафиксировано [ADR-009](decisions/ADR-009-data-first-route-intelligence.md)
  + [route-intelligence-roadmap.md](route-intelligence-roadmap.md) (P0–P4,
  плюс порядок будущего выделения сервисов: routing → AI → ingest).
- **Прод (crimeatrip-test):** импортировано 5000 реальных мест OSM
  (было 1000) и **210 фото** с лицензией CC0/CC BY/CC BY-SA (было 4).
- `import_place_photos.py --apply` падал с `NoReferencedTableError`
  (`media_attachments.uploaded_by_user_id` → `users`): скрипт импортировал
  только те модули, что использует напрямую, и SQLAlchemy не
  регистрировал таблицы, достижимые лишь через строковый ForeignKey.
  Исправлено импортом полного набора моделей, как в `alembic/env.py`.
- Добавлен фолбэк фото через тег `wikidata` → Wikidata P18 → Commons:
  прямые `wikimedia_commons`/`image` теги есть у ~0.1% элементов, а
  `wikidata` — у 6%. Кандидатов на батче в 5000 мест: 5 → 229.
- Чат: city-picker как bottom-sheet со всеми локальностями, чипы
  интересов «История»/«Природа», «Тревел Агент» обычным начертанием,
  типографика сообщений −1 размер.

### 2026-08-22 — AI-чат: баг-фиксы после ручного тестирования (фото, карусель, ползунки)

- **«Leg 0->1 exceeds max distance»**: воспроизвести на текущем коде не
  удалось (прямой прогон `pick_places_for_params` + `_route_places` на
  реальной БД для `Крым`/`Ялта`/`Симферополь` × всех `duration` × всех
  `transport_mode` — либо `OK`, либо чистый `insufficient_places`, ни разу
  raw routing error). Гео-chain-select в `place_picker.py` (уже был
  добавлен ранее, не в этом заходе) математически не даёт ни одному leg'у
  превысить лимит режима. Вывод: если баг всё ещё виден в приложении —
  скорее всего локальный backend-процесс не перезапущен после правки, не
  логическая ошибка. Если после рестарта баг повторится — нужен свежий
  repro (город/duration/transport_mode из реального запроса).
- **Маршруты/места без фото**: реальная причина — фото есть только у 4/20
  seed-мест, а `generate_service.py` при сборке AI-предложения хардкодил
  `cover_url=None` независимо от того, есть ли фото у выбранных мест.
  Добавлен `places/application/place_covers.py` (`covers_for_places`,
  `generic_fallback_cover`): подбирает фото выбранных мест, а если совсем
  ни у одной нет — использует любое существующее фото места как заглушку
  (как и просили — не оставлять карточку пустой). Подключено в
  `place_picker.pick_places_for_params` (заполняет `PickedPlace.cover_hint`,
  это поле раньше объявлено, но нигде не заполнялось) и `generate_service`
  (`cover_url` предложения + галерея карточки «собранного» маршрута теперь
  берёт фото всех точек, не только одно). `routes/application/service.py
  ._cover_urls_for_routes` (каталожные маршруты) тоже получил этот
  generic-fallback последним шагом.
- **Между карточками маршрутов в горизонтальном списке не было зазора**:
  `ChatCatalogMatchCarousel` использовал `PageView` с `viewportFraction: 1`
  (карточка = вся ширина, без просвета соседней). Теперь
  `viewportFraction: 0.94` + горизонтальный паддинг 5px на страницу — виден
  зазор и лёгкий пик соседней карточки; заодно гарантирует одинаковую
  ширину всех карточек (раньше тоже была одинаковой по высоте — фиксированный
  `SizedBox`, но без зазора это было незаметно).
- **Мало параметров в превью маршрута**: `RouteParamsBlock` показывал
  только бюджет/сложность/маршрут/расстояние. `stopsCount` и
  `durationMinutes` уже были в модели, но никогда не рендерились — добавлены
  строки «Время в пути» и «Точек маршрута» (и в каталожной карусели, и в
  карточке AI-предложения).
- **Ползунки/переключатели пересылали сообщение на каждое движение** (баг
  из [[ai-chat-fix-backlog]] п.1, ранее только зафиксирован, не
  исправлялся): теперь `ChatControlsGroup` копит изменения локально и
  отправляет одним чат-turn'ом по кнопке «Подтвердить» — на бэкенд всё
  ещё уходит по одному constraint-patch на контрол (контракт API не менялся),
  но в чат добавляется только последний ответ агента, не по одному на
  каждое движение слайдера/тумблера.
- Проверено: `flutter analyze`/`flutter test` (207/207), backend
  `pytest tests/security tests/unit -k "route_builder or route_match or
  routing or scoring or place"` — зелёные; живой repro-скрипт против
  реальной БД для фото/routing (см. выше).
- **Не реализовано в этом заходе, задокументировано как открытый вопрос**:
  карточка-ответ на «расскажи о месте» (факты + фото + ссылка на страницу
  места) — текстовый Q&A через `get_place_details` уже работает, rich-блока
  с фото/диплинком нет. План —
  [ai-route-chat-mobile-implementation.md](ai-route-chat-mobile-implementation.md)
  §«Открытый вопрос: карточка-ответ „расскажи о месте“».

### 2026-08-22 — Pixel-сверка чата и профиля с макетами

- Профиль (`Frame 146/147`): блок подписчиков — hairline-рамка вместо
  чёрной 2 px, высота пилюли 54 → 42, значение bold; «Звание:» серым,
  значение w700; прогресс — сплошная тёмная капсула (в макете заливка не
  визуализирует процент), 30 → 26 px, зазор до «Топ» 16; «Топ N» на
  `pageSurface`; высота карточки 155 (обычная) / 116 (эксперт); имя в
  шапке в две строки.
- Чат: чип «Подбор с ИИ» — сплошной `primaryBlue` вместо градиента
  (обновлён golden `mode_switch_morph_mid`); кнопки в пузыре 42 → 28 px с
  шагом 34; типографика пузыря 16 → 15 / заголовок 14 → 13; иконка
  отправки перерисована по макету; «Сегодня» над разделителем.
- Экран 2: параметры одной строкой «label value» (не выравнивание по
  краям), теги компактнее (3+1 как в макете), у превью рамка + разделитель.
- Экран 3: поля старт/финиш — белые с рамкой; «Локации собранного
  маршрута:» синим; галерея — лента превью вместо full-bleed фото;
  разделители по макету; «Посмотреть на карте» подключена (раньше колбэк
  никуда не был проброшен — кнопка не могла появиться).
- Кнопка «Новый чат» убрана из чата (её нет в макетах) → см. Next п.4.

### 2026-08-22 — Place photos (Wikimedia Commons) + LLM content enrich wired

- `scripts/import_place_photos.py` (новый, CLI dry-run → `--apply`): OSM
  `wikimedia_commons` / `image` теги → Wikimedia Commons `imageinfo` API →
  allowlist лицензий (CC0/PD/CC BY/CC BY-SA, всё остальное отклоняется) →
  скачивание → пересжатие в WebP (Pillow, capped edge/pixels, mirrors
  `routes/application/media.py`) → `media_attachments` (role=cover) +
  `place_images` (is_cover, author, license, source_url на Commons page).
  Ни один URL не запрашивается без предварительной проверки хоста
  (`commons.wikimedia.org` / `upload.wikimedia.org`) — ни на стадии
  `image=`-тега, ни на стадии самого запроса на скачивание.
- Новые модули: `places/application/photo_import.py` (чистый парсинг тегов +
  тонкий sync-клиент Commons API, license allowlist, HTML-strip для
  Artist/Credit), `places/application/photo_storage.py` (обработка + запись
  на диск), `places/application/place_images.py` (upsert `place_images`,
  переиспользует паттерн из `seed_crimea.py`). `media/application/service.py`
  `upsert_place_file_attachment` расширен опциональными content_type/
  byte_size/width/height/checksum.
  Публикацию мест это не меняет: `publication_status` не трогается.
- `scripts/enrich_places_content.py --llm`: `llm_callable=None` заменён на
  реальный вызов `LMStudioProvider.draft_place_content` (новый метод,
  JSON-only промпт под slug/short_description/description); если
  `AI_PLANNING_ENABLED` выключен или `AI_PROVIDER != lmstudio` — печатает
  причину и тихо откатывается на эвристику, батч не падает. Любая ошибка
  LM Studio на одном месте (timeout, битый JSON) → эвристика для этого
  места, без прерывания остальных.
- `structured_turn._extract_json_object` переименован в публичный
  `extract_json_object` и переиспользован в `draft_place_content` (тот же
  парсер JSON/```json-fence, что и в чат-турнах).
- Проверено: 23 новых unit-теста (`test_photo_import.py`) + 2 новых
  (`test_lm_studio.py`) — все зелёные; полный `pytest` 257 passed, Ruff/MyPy
  чистые. Живой smoke (не в CI): реальный вызов Wikimedia Commons API на
  «Ласточкино гнездо» (`File:Swallow's Nest (Crimea) 2007.JPG`, CC BY-SA 4.0)
  — скачано/пересжато/записано в `media_attachments`+`place_images`,
  `cover_image_url`-джойн из `places/application/service.py` отдал верный
  путь; тестовые строки и файл затем удалены. Локальная БД содержит только
  20 seed-мест (`source_name=seed`), поэтому массовый прогон не делался —
  это следующий шаг на контуре с OSM-импортом (1000 мест).

### 2026-08-21 — Backlog: place photos + LLM content enrich

- Зафиксировано к ближайшей реализации: импорт фото локаций из OSM/Wikimedia
  (и смежных источников с лицензией); довести
  `scripts/enrich_places_content.py --llm` для slug / description /
  short_description через локальную нейросеть (сейчас только эвристики +
  зарезервированный `--llm`).

### 2026-08-21 — AI chat match-first + design-spec screens + RAG pgvector

- Chat: catalog match before generate; `catalog_match` carousel; assembled
  proposal (start/finish/locations); stack starter actions; control_ack;
  seasonal tips only on AI fallback; tone mirroring in LM Studio prompt.
- Docs: product contract match-first; [ADR-008](decisions/ADR-008-rag-pgvector.md).
- Mobile: design-spec greeting, carousel, assembled card, silent controls,
  typing dots without bubble.

### 2026-08-21 — RAG on pgvector (ADR-008)

- Narrative chunks in Postgres: migration `0032_knowledge_chunks`, HNSW.
- Image: `crimeatrip/postgis-pgvector:16-3.4` (`docker/postgres`).
- Ingest: `scripts/ingest_knowledge.py --apply --embed`; retrieve hybrid
  (cosine + FTS fallback); chat wires `knowledge` DATA when `RAG_ENABLED`.
- Docs: [ADR-008](decisions/ADR-008-rag-pgvector.md).

### 2026-08-21 — Phase 8B stated-vs-draft constraints (no «Учли» strip)

- `confirmed_fields` = только явный ввод в чате; форма больше не сидится
  в confirmed. Первые interests из чата заменяют draft списка формы.
- LLM получает `form_draft_not_facts` отдельно. Полоску «Учли» убрали из UI.

### 2026-08-21 — Phase 8B agent loop, recommendations, sliders/toggles

- Docs: [ai-chat-agent-loop-and-recommendations.md](ai-chat-agent-loop-and-recommendations.md)
  (идеи пользователя + backlog).
- ToolRegistry: `search_places`, `seasonal_recommendations`; prefetch + до
  1 follow-up tool round в ходе chat turn.
- UI blocks: `recommendation_card`, live `slider` (бюджет), `toggle`
  (дети/питомцы); меньше quiz через `prefer_ready_ask_field`.
- Accept recommendation → merge city/interests/season в confirmed.

### 2026-08-21 — Phase 8B dynamic chips + confirmed constraints

- Session stores `confirmed_fields`; LLM видит только known/unknown, не
  дефолты формы как факты (антигаллюцинации «Ялта / на троих»).
- Structured JSON turn: `assistant_text` + `ask_field` + allowlisted
  `action_ids` + `constraint_patch`; chips динамические под вопрос.
- Chip `action_id` мержит patch в constraints; mobile — полоска «Учли…»,
  createSession без ложного confirmed city.
- Slider/toggle block types reserved (parse only); RAG/ToolRegistry — later.
- Migration `0031_session_confirmed_fields`.

### 2026-08-21 — Phase 8B session management (new chat)

- Sessions + messages already persisted (migration `0030`); owner BOLA.
- API: `GET /sessions`, `POST /sessions/{id}/close`,
  `GET /sessions/{id}/messages` (bounded pagination).
- Mobile: кнопка «Новый чат» — close текущей + create новой + очистка UI.
- Список прошлых чатов в UI — ещё не сделан (API list готов).

### 2026-08-21 — Phase 8B interactive chat (no canned greeting)

- Greeting → LLM с жёстким system prompt (без «Привет! У меня всё супер»).
- Короткое «давай»/confirm → deterministic generate + proposal card
  (place chips + кнопки), не free-form itinerary.
- Clarification replies несут action chips («Подбери маршрут», настроение).
- Mobile рендерит place chips + action chips; local canned только
  crisis/off-topic/injection.

### 2026-08-21 — Phase 8B first slice: planning sessions API

- Migration `0030`: `route_planning_sessions` + `route_planning_messages`.
- API: `POST/GET /route-builder/sessions`, `POST .../messages` (Travel+ +
  owner BOLA, topic guard SoT, input bounds).
- `AIPlanningProvider.chat_turn` + Mock + LM Studio (`reasoning_effort=none`);
  generate intent → existing deterministic `generate` + proposal card.
- Mobile AI chat: createSession + postMessage instead of generate-on-every
  message; accept/reject proposals unchanged.
- Flag still off by default; home-lab enable after deploy.

### 2026-08-20 — LM Studio home lab reachable (planning still off)

- WireGuard handshake ок, но server→Windows TCP к LM Studio нестабилен; для
  API выбран Windows-initiated SSH reverse + host→docker bridge forward
  (операционные команды — **только** на VPS
  `/opt/crimeatrip-test/HOME_LAB_START.md`, не в публичных docs).
- Prod: `AI_PROVIDER=lmstudio`, `LM_STUDIO_MODEL=gemma-4-26b-it`,
  planning/RAG **off**. `check_lm_studio.py` OK после `reasoning_effort=none`
  (Gemma 4 иначе заполняет `reasoning_content`, пустой `content`).
- Phase 8B (AI chat sessions в приложении) — следующий шаг.

### 2026-08-20 — WireGuard server PersistentKeepalive

- На VPS peer Windows добавлен `PersistentKeepalive = 25` (live `wg set` +
  `/etc/wireguard/wg0.conf`): сервер сам шлёт keepalive каждые 25 с.
- Если latest handshake всё равно стареет и `received` не растёт — на Windows
  туннель выключен или не шлёт пакеты; нужен активный WireGuard client с
  `PersistentKeepalive = 25` в его `[Peer]`.
- Дальше по плану LM Studio: свежий handshake → `/v1/models` →
  `check_lm_studio.py` → env в backend (planning/RAG пока off).

### 2026-08-20 — Match catalog seed (прод)

- Удалены mock `source_name=seed_user_routes` (15 шт. на проде).
- Добавлены 18 редакционных маршрутов `seed_match_catalog` под оси
  формы подбора (город, длительность, интересы, темп, транспорт, сезон,
  дети/питомцы). Реальные user_created (6) сохранены.
- Скрипт: `tourism-backend/scripts/seed_match_catalog_routes.py`.
- Scoring: алиасы `walk`/`walking`, `public`/`public_transport`, сезоны
  RU↔EN.

### 2026-08-20 — RoutingProvider stub + план OSRM по Крыму

- Application port `RoutingProvider` + `StubRoutingProvider` (haversine ×
  road factor, `synthetic=true`, typed `routing_unreachable` /
  `route_too_long`).
- Generate/accept вызывают routing до persist: `distance_meters`, synthetic
  LINESTRING, warnings в `accessibility.routing`.
- План self-host: `docs/routing-provider-osrm-crimea.md` (extract, compose,
  swap stub→OSRM). OSRM container ещё не поднят.
- ADR-004 ссылается на as-built stub и OSRM-план.

### 2026-08-20 — Place planning fields + OSM/content enrich CLI

- Миграция `0029`: crowding, price range, access_transport, parking,
  content enrichment provenance/`proposed_slug`, таблица `road_events`.
- `scripts/enrich_places_facts.py` — backfill фактов из Overpass
  `source_payload` (как продолжение `import_osm_crimea.py`).
- `scripts/enrich_places_content.py` — эвристические draft slug/описания
  (`generated_draft`); `--llm` зарезервирован под home-lab Gemma.
- API place detail/list отдаёт новые поля; docs bulk-import §2.5 обновлён.

### 2026-08-20 — Generate→черновик, расширенные поля, proposal в AI-чате

- Backend: `POST /route-builder/generate` (form → private `routes(source=generated)`
  draft; chat → proposal + blocks), accept/reject proposals, UsageCounter
  (free weekly 5 / Travel+ daily 30), миграция `0028`.
- Deterministic place picker по городу/интересам/сезону без LLM.
- Mobile: расширенные поля формы (сезон, транспорт, день, бюджет+, дети/питомцы);
  CTA генерации на результатах; AI-чат показывает proposal card с действиями.
- Owned routes API включает `source=generated`.

### 2026-08-20 — Три пути подбора + algorithmic match API

- Канон: params free/Travel+ → алгоритмический catalog match; Travel+ + AI →
  NN-ранжирование каталога; miss → генерация (квоты разные); AI-чат → proposal
  в сообщении (создать / черновик / уточнить). Документ:
  `docs/ai-route-match-three-paths.md`.
- Backend `POST /api/v1/route-builder/match`: детерминированный scoring
  публичных маршрутов (город, длительность, интересы, темп, сезон, транспорт,
  дети/питомцы), bands ideal/close, `offer_generate`.
- Mobile: форма «Подобрать» бьёт в match API; экран результатов показывает
  ranked hits и CTA генерации; виджет `ChatRouteProposalCard` для будущего
  chat-flow.

### 2026-08-20 — Travel+ AI-контракт, entitlements и топик-гард

- Канон преимуществ Travel+ / free для подбора и AI, топик-гард с типовыми
  ответами и сценарий proposal→accept→новый маршрут с place/proposal blocks в
  чате: `docs/ai-route-chat-product-contract.md`.
- Backend `EntitlementService`/`QuotaPolicy`: free vs Travel+ лимиты;
  `/me` отдаёт `ai_chat_enabled`, `max_route_points`, `alternatives_count`,
  `advanced_filters_enabled`.
- Mobile AI-чат: классификатор intent + canned replies (greeting / off-topic /
  injection / crisis) до вызова LLM.

### 2026-08-20 — Travel+ в БД и гейт «Подбор с ИИ»

- Добавлены `users.travel_plus_active` / `expires_at` / `plan` и таблица
  `travel_plus_subscriptions` (миграция `0027`): история периодов +
  денормализованный флаг для `/me`.
- API: `POST /me/travel-plus/activate` (mock checkout) и
  `POST /me/travel-plus/cancel`; SQLAdmin — выдача/снятие Travel+ и список
  подписок.
- Mobile читает статус из сессии/`/me`; раздел «Подбор с ИИ» и CTA открываются
  только при активной подписке, иначе — экран Travel+.
- Реальная оплата Store ещё не подключена; mock checkout пишет подписку в БД.

### 2026-08-20 — Топ путешественников, карточка локации и CI без push pipelines

- Экран «Топ путешественников» перевёрстан по макету: отдельная позиция
  текущего пользователя, пьедестал топ-3, целевые тп, экспертный стиль и
  переходы в публичный профиль.
- Карточка локации получила высокую галерею, действия «поделиться/избранное»,
  просмотр на карте, полное описание, предупреждения и реальные связанные
  маршруты через `GET /routes?place_id=...`.
- Отзывы локаций реализованы как отдельная сущность `place_reviews` (миграция
  `0026`): собственный закреплённый отзыв, модерация, ответы, до шести безопасно
  проверяемых фотографий, просмотр фото на весь экран и временное удаление
  собственного отзыва. Медиа опубликованного отзыва отдельно не удаляется.
- В SQLAdmin отзывы маршрутов и локаций разделены и явно показывают целевой
  маршрут/локацию; фотографии доступны в списке и деталях.
- Backend push pipelines полностью отключены на период малого остатка минут.
  Production теперь собирается и разворачивается локальной командой
  `tourism-backend/scripts/deploy-production-local.sh`; GitLab сохраняет лишь
  ручной registry-build через Run pipeline.
- 4-й раздел переименован в «Избранное», заголовок экрана — «Моё избранное»,
  а первая вкладка — «Маршруты». Маршруты, места и подписки используют общий
  двухступенчатый swipe: короткий жест фиксирует кнопку «Убрать», автоматическое
  удаление начинается только после 72% ширины; у каждого удаления есть undo.
- Активное и неактивное сердце теперь рисуются одним общим контуром: выбранное
  состояние лишь заполняет его белым, поэтому форма не меняется при toggle.
- Следом для карточки места: завести проверенный контракт аудиогида; для
  отзывов локаций — inbox/push о модерации и ответах.
- Проверки: mobile `flutter analyze` и полный `flutter test` — 190 passed,
  включая обновлённые pixel-goldens; backend полный `validate.sh` — Ruff,
  MyPy, pip-audit, 177 passed и coverage 75.08%; platform validate — green.

### 2026-08-20 — Design alignment: profile, cards and expert routes

- Убрана лишняя разделительная линия в подборе маршрута; у фильтров на
  главной явно заданы читаемые цвета обычного и выбранного состояния.
- На экране достижений уменьшены интервалы между карточками, а пустой
  результат поиска центрирован по ширине экрана.
- Карточки похожих маршрутов приведены к пропорциям общих route cards и
  уменьшены для горизонтальной ленты.
- Профиль получил более высокий фон и увеличенный блок подписок, звания и тп
  с исправленными вертикальными отступами. При pull-to-refresh фон, аватар и
  имя остаются неподвижны, а карточка статистики движется синхронно с
  контентом и не обрезается.
- Введён единый expert-style: сине-фиолетовая рамка, рамка аватара и бейдж
  «Эксперт» используются в карточках маршрутов и пользователей на главной,
  в поиске, профиле, рейтинге и подробностях маршрута.
- Публичная проекция маршрута теперь содержит `author_is_expert`; Flutter
  модель использует это поле во всех общих route cards. Регрессии закрыты
  widget/security тестами и обновлённым golden главной.
- Проверки: mobile `flutter analyze`, полный `flutter test` — `187 passed`;
  backend Ruff, MyPy и `175 passed`, coverage 75.30%.

### 2026-08-20 — Checkpoint Windows AI VPN и LM Studio API

- На сервере установлен WireGuard, поднят и включён в автозапуск интерфейс
  `wg0`: server `10.77.0.1/24`, Windows peer `10.77.0.2/32`, публичный endpoint
  использует только `51820/udp`.
- Windows-конфиг импортирован как split-tunnel; настроен
  `PersistentKeepalive = 25`. Handshake и двусторонний служебный трафик
  подтверждены. Клиентский приватный ключ и копия конфига удалены с сервера.
- LM Studio Desktop слушает `0.0.0.0:1234`; Windows Firewall ограничивает
  входящий TCP 1234 адресом сервера `10.77.0.1` на WireGuard-интерфейсе.
- `LM_STUDIO_API_KEY` вручную сохранён в `/opt/crimeatrip-test/.env` с mode
  `600`; значение не выводилось, не логировалось и не попадало в Git. Текущий
  backend-контейнер после этого не перезапускался.
- Backend один раз получил ожидаемый `401` от
  `http://10.77.0.2:1234/v1/models`, чем подтверждён полный сетевой путь до LM
  Studio. Повторные TCP-соединения пока нестабильны и иногда истекают по
  connect timeout; авторизованный `/v1/models`, model ID и chat completion ещё
  не подтверждены.
- Следующее продолжение начинать с tcpdump на `wg0:1234` и проверки активных
  Windows Firewall/сторонних VPN rules. Затем получить точный model ID,
  выполнить `scripts/check_lm_studio.py` и только после успешного smoke-теста
  обновить/recreate backend-контейнер. `AI_PLANNING_ENABLED` и `RAG_ENABLED`
  остаются выключенными.
- Отдельный ops-gap: на текущем Ubuntu-хосте `ufw` не активирован, INPUT policy
  — ACCEPT. Не включать UFW без аудита SSH `6579`, Caddy и Docker chains;
  подготовить отдельный безопасный firewall hardening.

### 2026-08-19 — PostGIS bulk import и Windows LM Studio home lab

- Добавлена инструкция для Windows AI-ПК: LM Studio + фактически выбранная
  Unsloth Gemma 4 26B A4B it UD-IQ4_XS, localhost smoke, API token и
  private-network подключение backend без прямого доступа модели к БД.
- Уточнено, что LM Studio Bionic — отдельное приложение: Bionic остаётся для
  агентов, а управляемый OpenAI-compatible API запускается в обычном LM Studio
  Desktop. Зафиксирован split-tunnel WireGuard
  `server 10.77.0.1 ↔ Windows 10.77.0.2` без публикации порта 1234.
- Реализован фундамент импорта 1000+ мест: provenance/source identity, честный
  `payment_status`, planning-поля, data quality status и серверные фильтры.
- Добавлен OSM/Overpass normalizer и CLI: dry-run по умолчанию, `--apply`
  создаёт только unpublished drafts; сырой payload и лицензия сохраняются.
- Зафиксирован будущий mobile AI-чат: session API, typed progress, состояния
  кнопки генерации, idempotency и deterministic fallback.
- Миграция `0025` применена локально; импортировано 1000 уникальных OSM places
  как `draft/auto_validated`. Повторный импорт дал `created=0, updated=1000`.
  Все 169 backend tests зелёные, coverage 75.01%, Ruff/MyPy зелёные.
- Backend `354a466` развёрнут на test/production-контуре. Ручной job собрал
  13 647 OSM-объектов непосредственно на сервере и записал 1000 новых places;
  SQL-контроль: `draft/auto_validated = 1000`. Public health ready, каталог
  продолжает возвращать только 20 опубликованных редакционных мест.
- Backend `0aee04c`: добавлены реальные LM Studio settings, provider-neutral
  contract и smoke probe `/v1/models` + `/v1/chat/completions`. Токен не
  логируется; planning endpoint ещё выключен. Backend gate: 175 tests,
  coverage 75.30%, Ruff/MyPy зелёные.
- Следом: authoritative region boundary, spatial containment, dedup и
  enrichment человекочитаемых slug/описаний через Gemma с provenance,
  затем редакционный quality gate перед публикацией.

### 2026-08-19 — Expert profiles, review media/replies and admin polish

- Backend migrations `0020`–`0024`: durable `users.is_expert` with
  `user_expert_status_events`; review photos in `media_attachments`; nullable
  `route_reviews.reply_to_review_id`; inbox/push kind `review_reply` after
  moderation; `expert_granted` / `expert_revoked` after an actual expert-status
  transition. Reply targets must be a published review of the same route.
- Review media: JPEG/PNG/WebP validation, 10 MB input and six-photo limit.
  Selected local photos can be removed only in the composer before sending;
  server media mutation is locked after publication. Deletion of the whole
  review keeps the six-hour window.
- Mobile route comments: own root review is pinned and suppresses the new
  review form; replies use a cancellable quoted context; published quotes are
  persisted; photos open in a swipeable/pinch-zoom fullscreen viewer and have
  no delete control on submitted cards.
- Admin: review photo thumbnails + fullscreen viewer; filter sidebars are
  collapsed by default; expert status can be changed in the user form or by
  audited bulk actions. Both paths create an in-app notification and attempt
  FCM delivery when the user enabled push and has a registered token.
- Planned next, not implemented: DB-managed notification templates/campaigns
  with SQLAdmin preview/test/send, audit and idempotent audience delivery
  (`T6.5.3`). Existing event notifications remain code-defined for now.
- Profile/search UI: expert gradient avatar/rank borders, own vs public
  follower stats, corrected follower SVG and 2 px stat borders; search
  carousels use the full viewport. Top-traveler cards now paint shadows on a
  separate rounded layer and clip their Material surface. Pull-to-refresh moves
  the expanded identity and rank/follower card as one group with the cover.
- Mobile release `0.1.12+13`: temporary «Крымская коровка» launcher
  artwork is installed for Android and iOS; the home-screen label is
  `КРЫМТРИП`. A signed, obfuscated production/API arm64 APK was built for
  Xiaomi/Redmi, and the same release was installed on the physical iPhone.
- Verification: mobile `flutter analyze` clean and Flutter tests green;
  backend Ruff/compile green. Backend changes deploy through the normal GitLab
  pipeline; release verified on the physical iPhone target.

### 2026-08-18 — Achievements API, OTP reuse, profile/search polish

- Backend: каталог `achievements` + `user_achievements` (migration `0019`);
  `GET /users/{id}/achievements`; starter-grant 5–15 бейджей при регистрации
  и inbox/push `achievement_unlocked`. Award-правила по прохождениям —
  по-прежнему после Phase 9.
- Public profile: реальные `followers_count` / `following_count` из
  `profile_likes`; дефолтные avatar/cover, если медиа нет.
- Auth: повторный `POST /auth/otp/request` при живом challenge **не**
  выпускает второй код (reuse + Redis lock); то же для смены телефона.
- Mobile: fullscreen-поиск (история — последний запрос сессии, карусели
  на всю ширину, шторка фильтров); профиль без Travel+ баннера; карусель
  только полученных ачивок; отзывы маршрута по макету; серый placeholder
  вместо вспышки mock-фото.

### 2026-08-18 — Docs: as-built stack + Gemma 4 home lab

- Канон стека: [stack.md](stack.md) — local DX, test host (Caddy/PostGIS/
  Redis), CI lean, целевой Ollama **`gemma4:12b`** (не на test-VPS).
- README workspace/platform/backend/mobile, container diagram, system
  context, local-development, repository profiles — сняты claims
  «foundation skeleton» / «deploy не реализован».
- `AI_PROVIDER`: `mock|gemini|ollama` (алиас `self_hosted` устарел).

### 2026-08-06 — Lean CI default (историческая запись)

- Default `.gitlab-ci.yml` is **lean**: notice + backend publish/manual
  deploy; mobile APK manual-only; platform notice. Feature branches skip CI.
- Full DevSecOps moved to `.gitlab-ci.full.yml`; enable with
  `CI_PIPELINE_MODE=full`.
- Local gates: `./scripts/validate.sh` + Cursor skill
  `travel-platform-local-ci`. Doc: [ci-and-runners.md](ci-and-runners.md)
  (includes self-hosted runner notes — prefer not on prod host).
- С 2026-08-20 эта схема заменена более строгим режимом: backend push pipeline
  не создаётся вовсе, а deploy выполняется локальной отдельной командой.

### 2026-08-06 — CI DevSecOps green-up + admin datetime format

- Backend: `backend-security-tests` seeds Crimea + `--no-cov` (subset must
  not inherit suite `cov-fail-under`); Semgrep retry + empty entrypoint.
- Mobile: `.gitleaks.toml` allowlist for public Firebase client config;
  OSV uses `/osv-scanner`; Semgrep retry.
- Platform: `.gitleaks.toml` allowlist for Figma `fileKey` inventory;
  markdown table fix in implementation-plan.
- Admin UI dates: `YYYY-MM-DD HH:MM:SS МСК` (no fractional seconds); DB
  still UTC.

### 2026-08-06 — CI DevSecOps + signed APK artifacts

- Backend: dropped redundant `backend-image`; `uv` cache; dedicated
  `backend-security-tests`; gitleaks + Semgrep (ERROR) gate publish; Trivy
  HIGH/CRITICAL after publish gates deploy.
- Mobile: gitleaks + Semgrep + OSV on `pubspec.lock`; `mobile-apk-test` builds
  signed test APK (CI keystore vars) → GitLab Job Artifact (14d) on
  main/gamma. No public host download in this iteration.
- Platform: `platform-gitleaks`.
- Docs: [security-testing-guide.md](security/security-testing-guide.md),
  [mobile-build-and-install.md](mobile-build-and-install.md).

### 2026-08-06 — Doc sync with as-built code

Code audit vs living docs. Corrected stale claims:

- **Profile progress:** ranks (`travel_ranks`), тп, leaderboard, profile
  likes — durable API + mobile (`DATA_SOURCE=api`). **Achievements** carousel
  remains mock (deferred; rest of Phase 14).
- **Route publication:** draft → media → submit → SQLAdmin approve/reject →
  public catalog + inbox (`route_published` / `route_rejected`) — shipped;
  not a stub / not “Phase 11 only”.
- Still **stub / UI-only:** route builder/match results (catalog slice),
  route execution CTA, Travel+ entitlements/billing, audio guide play,
  offline download, «Мои маршруты → История». Favorites + profile follows
  on that tab are real; own publications surface on **profile** via
  `/routes/mine`.

### 2026-08-06 — FCM tray: egress + OAuth without requests

- Root cause: backend on `private` (`internal: true`) could not reach Google
  FCM/OAuth; in-app inbox still worked. Compose: backend also on `edge`.
- FCM sender rewritten to PyJWT + httpx (no `requests` /
  `google.auth.transport.requests`). Verified `fcm_send_ok` / `sent 1` on
  test host with a live device token.

### 2026-08-06 — Push toggle ↔ OS notification permission

- Settings «Пуш-уведомления» reflects `AuthorizationStatus` (Android 13+ /
  iOS); denied → subtitle + dialog to open system notification settings
  (MethodChannel). Token sync only after OS grant.

### 2026-08-05 — Inbox badge + foreground toast

- Home bell shows unread count badge; shell polls inbox every 30s while
  resumed and shows a top in-app toast for newly arrived unread rows.
- System tray push (FCM/APNs) still requires iOS Firebase/APNs setup.

### 2026-08-05 — Multi-reviews, 6h delete, profile_like inbox

- Reviews: drop unique `(route, author)`; POST updates only pending, else
  inserts; `DELETE /routes/{id}/reviews/{review_id}` within 6h of `created_at`.
- In-app `profile_like` on first profile like; target_type `user`.
- Migration `0018_reviews_profile_like`. Mobile: delete UX, full-width review
  sheet, inbox deep link to liker profile.

### 2026-08-05 — Moderation inbox kinds (routes + reviews)

- In-app kinds: `route_published` / `route_rejected` (владелец маршрута),
  `review_published` / `review_rejected` (автор отзыва); `route_review`
  по-прежнему только когда отзыв оставил другой пользователь.
- Migration `0017_notif_moderation_kinds`.

### 2026-08-05 — Route reviews + in-app notifications + FCM scaffold

- Backend: `route_reviews` + `notifications` (migration `0015`),
  public/list/submit review API, `/me/notifications` inbox, moderation approve
  creates owner **in-app** notification.
- Admin: раздел «Отзывы» с approve/reject; FK user/route показывают имя + ссылку.
- Mobile: отзывы на деталях маршрута, inbox из API с переходом в маршрут
  (**работает на iOS и Android** — HTTP + UI, без tray).
- FCM каркас: migration `0016_device_tokens`, API `/me/device-tokens`, optional
  FCM HTTP v1 send на approve; mobile `firebase_core`/`firebase_messaging` +
  stub `firebase_options` (`configured = false`). Docs:
  [push-notifications-fcm.md](push-notifications-fcm.md).
- **Блокер для system push:** создать проект в Firebase Console,
  `google-services.json` / `GoogleService-Info.plist`, `flutterfire configure`,
  service account в `FCM_SERVICE_ACCOUNT_*` (не в Git).

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
| 6 | Authentication | in_progress |
| 6.5 | Internal ops admin (SQLAdmin) | done |
| 7 | Favorites and profile | done |
| 8A | Deterministic Route Builder | pending |
| 8B | AI-assisted Route Planning (experimental) | pending |
| 9 | Route execution | pending |
| 10 | Stabilization and staging | pending |
| 11 | User-created routes (publish + moderation) | in_progress |
| 12 | Travel+ foundations | in_progress |
| 13 | Trip Planner | pending |
| 14 | Traveler progress (catalog as-built; award rules remain) | in_progress |

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

### Ближайшие продуктовые приоритеты (2026-08)

1. **Phase 8A** — deterministic Route Builder (сейчас match UI + срез каталога).
2. **Phase 9** — прохождение маршрута («Пройти маршрут» → soon).
3. Polish: «Мои маршруты → История»; SMS OTP provider; iOS APNs; Stage host /
   backup smoke.
4. **Phase 14 remainder** — award pipeline достижений (события / Phase 9
   executions); каталог и карусель уже с API.
5. Phase 12 Travel+ entitlements (paywall пока mock).

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
  каталогу не пересоздаёт navbar. На подробностях точки navbar теперь плавно
  схлопывается до активной Map-капли; первое нажатие раскрывает все сегменты,
  повторное нажатие «Карта» возвращает каталог с сохранённым branch state.
- Поиск на Home теперь открывает отдельный fullscreen-экран с секциями
  маршрутов, мест и путешественников. Поиск в «Места Крыма» использует
  debounce и параметр backend API `q`; mock repository поддерживает тот же
  контракт. Оба поля имеют явную очистку и состояния «ничего не найдено».
  Закрытие поиска: крестик в поле и tap outside (`TapRegion`). Routes catalog
  остаётся inline-search (без fullscreen `showSearch`).
- Назад с места, открытого из маршрута, возвращает в route details
  (`/routes/:id/place/:placeId`), а не в каталог мест. Detail pages —
  `CupertinoPage` для iOS edge-swipe.
- Основные и круглые команды на iOS — Flutter frosted glass (`BackdropFilter`);
  поиск/фильтр/колокольчик на светлых экранах — `controlSurface` как в Figma.
  Native `UIGlassEffect` через `UiKitView` отключён: platform view размывает
  native backdrop (тёмный), а не Flutter-пиксели. `AppFloatingNavBar`
  остаётся Flutter-owned.
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
- Current mobile gate after native Liquid Glass controls: format/analyze
  passed, `63 tests` and all 13 macOS pixel goldens passed. Release mock
  build reinstalled on physical iPhone (iOS 26.5).
- Profile tab: Figma layout with cover/avatar, rank card, achievements
  carousel, published routes carousel; text-only for untrusted strings.
  **As-built (api mode):** name/avatar/cover, favorites summary, ranks/тп/
  leaderboard place, profile likes, own routes via `/routes/mine`,
  achievements carousel from API — durable.
- Home header avatar/greeting area now opens Profile; OTP consent rows are
  taller with centered checkbox/checkmark hit area for cleaner alignment.
- Swipe deck no longer visually jumps after dismissing onboarding coach card:
  added dedicated `coachDismiss` settle path + regression test coverage.
- GitLab CI split completed in all repositories (`workspace`, `tourism-mobile`,
  `tourism-backend`, `tourism-platform`): `code-style` and `run-tests` jobs are
  now separated (build/publish stages preserved where applicable).
- GitHub showcase mirror: public repos under `xotabeach/*`; GitLab CI
  `github-mirror` stage syncs `gamma`/`main` on push after green checks
  (token via group CI variable `GITHUB_MIRROR_TOKEN`).

- In-memory API cache for places and routes (lists 5 min TTL, details 10 min).
  Caching decorator over repository interfaces; global invalidation on logout;
  clear-cache action moved to Settings → Offline.
- Settings UI polished to Figma screenshots (2026-07-29): Travel+ banner on
  top, separate icon cards, dark circular back/check, blue chat CTA, offline
  trash clear-cache, Travel+ paywall hero + plan cards.

Остаётся: сверка approximate values и original SVG через Figma Dev Mode,
device screenshot diff, performance profile на mid-range Android; Freezed
optional. Pixel-perfect статус не заявлен без этих проверок.
См. [flutter-app-architecture.md](flutter-app-architecture.md).

### Phase 5.5–5.6 — Environments and first remote test server

До Phase 6 нужно унифицировать `local/test/staging/production`, отделить
mobile data source и AI provider от runtime environment, затем развернуть
immutable backend image из `main` (GitLab `production`) на удалённый сервер;
`gamma` → `stage` (publish, без деплоя на сервер). Слабый узел использует
constrained Compose, swap, один worker, HTTPS reverse proxy, закрытые data
ports, миграционный job, health/smoke checks и off-host test backup. MinIO,
пользовательские данные и AI в этот контур не входят.

Подготовлено в коде: backend `APP_ENV` enum и immutable image с seed/media;
mobile `APP_ENV` + `DATA_SOURCE` с запретом mock вне local; publication image
по commit SHA; constrained Compose и `deploy-remote.sh`. Первоначальная схема
CI имела publish/deploy jobs на `main`/`gamma`; с 2026-08-20 backend push
pipelines отключены, а та же безопасная доставка вызывается локальным
`deploy-production-local.sh`.

Проверки 2026-07-26: backend validation `42 passed`, coverage 89.11%,
pip-audit без известных уязвимостей; runtime image собран локально, seed/media
проверены. Mobile validation `56 tests`, test/API iOS Simulator build passed.
Platform local и constrained test Compose config passed. Remote bootstrap ждёт
ротации первоначального пароля, SSH deploy key и подтверждённого TLS hostname;
host inventory и credentials в Git не сохраняются.

Remote contour поднят 2026-07-28: host bootstrap (1 GiB swap, Docker),
immutable image, migrate + Crimea seed, Caddy HTTPS. SSH на нестандартном
порту (не 22). Smoke: `/health/live`, `/health/ready`, places/routes API —
200. Добавлены non-root deploy user + CI SSH deploy с `main` /
`production`. Остаются: отдельный stage-хост, off-host backup/restore smoke
и key-only hardening review.

### Phase 6–7 — Auth + favorites (partial, 2026-07-28)

- Backend: phone OTP (`/auth/otp/request|verify`), JWT access + opaque refresh
  (rotation + reuse detection), `/me`, favorites places/routes. SMS provider —
  TODO. 2026-07-31: real OTP on the test contour
  (`AUTH_OTP_ACCEPT_ANY` default off for `APP_ENV=test`); readable
  `debug_code` only via `AUTH_OTP_STORE_DEBUG_CODE` on local/test
  ([SEC-EX-2026-001](security/exceptions/SEC-EX-2026-001.md)); staging/prod
  refuse both shortcuts at startup; constant-time digest compare.

### Phase 6.5 — Ops admin SQLAdmin (2026-08-01)

- Backend: SQLAdmin at `/admin` ([ADR-008](decisions/ADR-008-ops-admin-sqladmin.md));
  `admin_principals` / role bindings / audit events; Argon2id; cookie session
  with Origin/Referer/Sec-Fetch-Site CSRF; bootstrap via `ADMIN_BOOTSTRAP_*`;
  views for users, OTP (`debug_code` gated), phone-change, support + operator
  reply, audit.
- Security tests: `tests/security/test_admin_security.py`.
- 2026-08-01: CrimeaTrip theme (Rubik, `#386FC4` / coastline sidebar, Russian
  IA groups Пользователи / Поддержка / Доступ); ProxyHeaders for HTTPS statics.
- 2026-08-01 (follow-up):
  - Users: edit (name/phone/тп/notify flags) with audit `admin.user_update`;
    list shows avatar + cover thumbs from `media_attachments` (only `/media/`
    paths); filters by phone and user id.
  - OTP: default sort newest-first; filters by phone and linked `user_id`
    (join on `users.phone_e164`).
  - Support ticket details: bubble chat UI (user left / operator right) with
    inline operator compose; messages still via `SupportMessage` +
    `operator_reply`.
  - Theme polish: hub cards, chat shell, user media cells.
- Mobile: secure refresh storage, Dio Bearer + single-flight refresh, OTP UI
  wired to API, profile shows durable name + favorites summary.
- Follow-ups (through 2026-08): `travel_ranks` + delayed +5 тп (profile like /
  route favorite); public profile/leaderboard/subscriptions APIs; ranks and
  тп on profile are API-backed. Achievements catalog + carousel — as-built
  2026-08-18; event unlock rules remain.
- Route publication (ahead of original Phase 11 plan): drafts, media upload,
  submit for review, SQLAdmin approve/reject, inbox kinds, mobile
  `route_publish` → `/routes/drafts` + `/routes/{id}/submit`; own routes on
  profile. Remaining Phase 11 polish: owner drafts queue in «Мои маршруты»,
  history tab (still catalog placeholder).
- 2026-07-30: `media_attachments` table (canonical media links); public
  `GET /users/{id}` + `/routes`; catalog includes public `user_created`;
  seed three routes per user; mobile image disk/memory cache; author → view-only
  profile.
- Security as-built doc:
  [security/security-as-built.md](security/security-as-built.md) — auth tokens,
  API/mobile controls, injections, media, gaps; baseline/topic docs refreshed
  (`security-baseline`, auth/API/mobile/media topic pages).
- Security tests: auth/favorites BOLA + OTP input bounds; mobile session tests.
- Settings/Support/Travel+ UI aligned to pixel spec
  [figma-spec-settings-support-v2.md](design/figma-spec-settings-support-v2.md)
  - QA handoff [banner-flutter-diff-v3.md](design/banner-flutter-diff-v3.md):
  accent `#386FC4`, tile radius 14, 64/52 rows; Travel+ banner — soft disk at
  C≈(353.7,131), **no** solid concentric rings, dashed arc 90° (9→12 o'clock)
  with flat-outer/round-inner dashes `#1537E7`, nav cursor on arc, chip fill
  white 18%, shared title/+ gradient. Year/month cards 361×72. Copy follows
  Figma including typos (`удоства`, `Поддерка`, `Асистент`, `измененно`,
  `Сохранить новое номер`) pending product decision to correct.

### Shell / profile polish (2026-08-01)

- Floating nav: liquid collapse/expand restored to original lerp + icon
  `translationX` motion (detail/settings only). Guest/other profile keeps
  **full** nav; Home slot becomes history-back (`pop`, same as edge swipe).
  Scroll-down on a tab shows scroll-to-top glyph on the active item.
- Support chat: operator replies refresh every 3 seconds while the screen is
  active; refresh stops in background and runs immediately after resume. The
  composer is pinned above the keyboard, preserves focus after sending, and
  scrolls to the newest message. The floating nav is hidden only on
  `/profile/settings/support/chat`.
- Detail screens: routes, places, and profiles use a shared pinned collapsing
  hero header. Scrolling fades media and expanded actions into a compact title
  bar while retaining the detail page's native content scroll.
- Home sticky «КРЫМТРИП» bar: shorter under Dynamic Island, fully opaque.
- Swipe coach: smaller arrows shifted in swipe direction; tap/finger glyph
  much smaller.
- Profile: smaller banner, rank divider, like control on guest profile;
  delayed travel points (+5 after 6h for profile like and route favorite) —
  backend migration `0011_travel_points` + mobile API wiring.

См.
[environment-and-backend-deployment.md](environment-and-backend-deployment.md).

### Design handoff — новые экраны (2026-08-03 → as-built 2026-08-06)

PNG-пакет: `docs/design/screens-figma/krymtrip-2/`.
Gap backlog: [design-gap-backlog-2026-08-03.md](design/design-gap-backlog-2026-08-03.md).

- Nav compose (+ → Опубликовать / Подобрать); places вне tab bar.
- **Публикация** — полный API+UI flow (не stub).
- **Подбор** — форма + UI результата; логика = срез каталога до Phase 8A.
- **Моё избранное** — маршруты, места и подписки реальные; для всех трёх
  разделов есть безопасное swipe/remove + undo. История — placeholder.
- Travel+ / AI-chat — UI mock only.

### Документировано (не реализовано): AI route planning

Архитектура и ADR-006: provider-neutral AI, Gemini experimental → Gemma + RAG,
editorial-first, form/chat → `NormalizedRouteRequest`, MCP отложен.
См. [ai-route-planning-architecture.md](ai-route-planning-architecture.md).
Home lab (Ollama + Qdrant, PostGIS vs RAG, Lab-0…5, RTX ~12 GB):
[ai-self-hosted-home-lab.md](ai-self-hosted-home-lab.md).
Сквозной поток запрос → промпт → параметры → RoutingProvider → маршрут,
форматы хранения и наполнение баз:
[ai-route-system-end-to-end.md](ai-route-system-end-to-end.md).
Реализация — Phase 8B+ / Future; не часть текущего UI polish.

## Блокеры и заметки

- Auth strategy: **ADR-007** implemented for mobile (JWT + opaque refresh).
  Remaining Phase 6: real SMS provider (test contour uses OTP/debug paths).
  Cookies later for web (admin already cookie-session).
- Routing provider — open decision (ADR-004); Phase 8A not started (empty
  `route_builder` / `route_execution` / `subscriptions` packages).
- Не коммитить `.tmp-ref-frames/` и локальные `.env`.
- AI architecture + home-lab guide documented; adapters not in backend yet.
  Сводка: [stack.md](stack.md). Test-VPS без Ollama.
- DX: style guides + Cursor workspace settings — see
  [development-environment.md](development-environment.md).
- Security: docs + Cursor skill/rule under
  [security/security-baseline.md](security/security-baseline.md). **Not**
  claimed complete; Redis ACL/prod hardening still open.
- Android CI APK job готов; для артефакта нужны GitLab CI variables
  (`ANDROID_KEYSTORE_*`, `MOBILE_TEST_API_BASE_URL`). Physical-device
  Impeller profile не выполнен.
- iOS system push: Firebase/APNs credentials still needed beyond Android FCM.

## Документировано (не реализовано): Security Baseline

Threat model, data classification, API/mobile/storage security docs, ADR-007,
incident response, CI recommendations. Foundation code: input limits, prod
placeholder-secret guard, security pytest, pip-audit job. Full auth — Phase 6.

## Как вести этот файл

1. При старте фазы: статус → `in_progress`.
2. При завершении: итог в «Что сделано», таблицу обновить.
3. Блокеры писать сразу.
4. Детальный backlog — в implementation-plan.
