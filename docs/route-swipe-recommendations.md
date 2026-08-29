# Маршруты-слайдер: рекомендации, конечная колода, ежедневное обновление

Статус: **backend v1 сделан 2026-08-29; mobile ещё на клиентской колоде** (2026-08-25).
Клиентская часть, которая не требует бэкенда, уже в `main` (см. «Что уже
сделано» ниже). Серверная колода, skip и ranker v1 готовы; приложение пока
не ходит в новый API.

Канонический общий контекст и Definition of Done: [implementation blueprint](implementation-blueprint-2026-08.md)
и [ADR-011](decisions/ADR-011-personalized-route-recommendations.md).

Связанные документы:

- [route-intelligence-roadmap.md](route-intelligence-roadmap.md) —
  `INTEREST_CATEGORIES` / `TRIP_TYPE_CATEGORIES` в `scoring.py`,
  которые этот документ переиспользует как категорийный профиль.
- [ADR-009](decisions/ADR-009-data-first-route-intelligence.md) —
  принцип «данные раньше семантики», которому следует и алгоритм v1
  здесь (никаких эмбеддингов — `places`/`routes` их ещё не имеют, P1
  в roadmap ещё не сделан).
- [flutter-app-architecture.md](flutter-app-architecture.md)

## Контекст

`RouteSwipeDeck` (`tourism-mobile/lib/features/routes/presentation/widgets/route_swipe_deck.dart`)
показывает карточки маршрутов из простого `routesListProvider` —
плоский список без персонализации. До сегодняшнего дня «пропуск»
(свайп влево) не убирал карточку насовсем, а **отправлял её в конец
колоды** (`_deck.add(route)` в `_finishSwipe`) — колода была
бесконечной, что и создавало ощущение шаффла, а не рекомендаций.

**Что уже сделано сегодня (клиент, без бэкенда):**

- Пропуск теперь необратимо убирает карточку — колода конечна
  (`_finishSwipe` в `route_swipe_deck.dart`).
- Уже избранные маршруты в колоду не попадают —
  `RoutesCatalogScreen._visibleRoutes` фильтрует по
  `favoriteRouteIdsProvider` до применения категорийного фильтра.
- Экран «конца колоды» — `_DeckExhaustedView`: иконка, текст «Вы
  разобрали все маршруты на сегодня» + подпись «Новые подборки
  появляются каждый день», кнопка **«Открыть список маршрутов»**
  (`onOpenAllRoutes` → `AllListScreen` в режиме `.routes`, тот же
  экран, что открывает «Смотреть все» на Главной).
- Тесты: `test/features/route_catalog_state_test.dart` (конечность
  колоды, исключение избранного, кнопка выхода на список).

**Backend v1 (2026-08-29) готов:** ranker, таблицы, `GET .../today`,
skip feedback и ленивая генерация. **Mobile R2 ещё нет:** приложение
по-прежнему берёт общий каталог и не шлёт skip на сервер. Host cron
на 03:00 МСК не установлен; без него колода считается при первом
запросе за день.

**Область действия:** только маршруты (`RouteSwipeDeck`). У мест
(«Локации») отдельного свайп-интерфейса в приложении нет — только
листалка/список. Формулировка «вы разобрали все локации на сегодня»
из исходного запроса, видимо, разговорная (на экране — маршруты); если
понадобится свайп-подбор и для мест, это естественное расширение той
же схемы (см. «Открытые вопросы»), но отдельная задача.

## Цели / не-цели

**Цели v1:**

- Каждому пользователю — свой ежедневный конечный список кандидатов,
  а не общий список всех опубликованных маршрутов.
- Не показывать то, что уже решено: избранное (уже готово на клиенте)
  и недавно пропущенное (нужен сервер, см. cooldown ниже).
- Простой, объяснимый скоринг на типизированных колонках и сохранённых
  персональных предпочтениях — без эмбеддингов и ML-обучения (это уже P1/P4 в
  route-intelligence-roadmap.md, отдельная инициатива).

**Не-цели v1:**

- Не тюнить веса моделью/A-B — начинаем с ручных весов, коллекция
  сигналов (`route_recommendation_feedback`, см. ниже) — это задел под
  обучение позже, а не то, что v1 обязано использовать.
- Не делаем real-time пересчёт при каждом свайпе — колода на день
  фиксируется один раз батчем в 03:00 МСК.
- Не проектируем сейчас свайп для мест — только маршруты.

## Данные: чего не хватает

Модели `Route` / `FavoriteRoute` уже есть
(`tourism-backend/src/tourism_backend/modules/routes/infrastructure/models.py`,
`favorites/infrastructure/models.py`). Категорийный профиль маршрута
на самом маршруте не хранится — он собирается через
`route_stops → place_id → place_categories → categories`. Completions
читаются из `route_executions` (cooldown 30 дней). Таблицы колоды и
skip уже в миграции `0042_route_recommendations`. Исходный SQL ниже —
спецификация; as-built добавляет `client_event_id`, `explanation_code`
и уникальность `(user_id, client_event_id)`.

Нужны две новые таблицы (миграция Alembic, как остальные — см.
`alembic/versions`):

```sql
-- Единственное новое действие, которого сейчас нет нигде: пропуск.
-- "favorite" как позитивный сигнал уже читаем из favorite_routes —
-- отдельно его не дублируем.
CREATE TABLE route_recommendation_feedback (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    action VARCHAR(16) NOT NULL CHECK (action IN ('skip')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_route_reco_feedback_user_route
    ON route_recommendation_feedback (user_id, route_id, created_at DESC);

-- Предвычисленная колода на день — считается батчем, читается запросом.
CREATE TABLE route_recommendation_deck_items (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    route_id UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    deck_date DATE NOT NULL,        -- дата в МСК, не UTC
    rank SMALLINT NOT NULL,
    score REAL NOT NULL,            -- для отладки/будущего анализа
    UNIQUE (user_id, deck_date, route_id)
);
CREATE INDEX ix_route_reco_deck_user_date
    ON route_recommendation_deck_items (user_id, deck_date, rank);
```

`deck_date` — календарная дата **в МСК** (не UTC), чтобы «сегодняшняя
колода» совпадала с интуицией пользователя независимо от серверного
часового пояса.

## Алгоритм v1 (без ML, без эмбеддингов)

Кандидаты: `routes.publication_status = 'published' AND visibility =
'public'`, минус уже избранные (`favorite_routes`), минус пропущенные
за последние **14 дней** (cooldown — не навсегда: у пропуска нет
семантики «никогда», интересы меняются; 14 дней — стартовое значение,
см. открытые вопросы).

Для каждого кандидата считаем `score`:

```text
score =
    0.30 * explicit_preferences +   -- ответы quiz из users.travel_preferences
    0.25 * category_affinity   +   -- пересечение категорий маршрута
                                    -- (через его stops → places) с
                                    -- категориями избранных маршрутов
                                    -- и мест пользователя
    0.15 * region_affinity     +   -- 1.0 если регион маршрута совпадает
                                    -- с самым частым регионом среди
                                    -- избранного пользователя, иначе 0
    0.15 * popularity          +   -- log(1 + count(favorite_routes
                                    -- по этому route_id)), нормировано
    0.15 * freshness               -- экспоненциальный спад по
                                    -- published_at/created_at, свежее
                                    -- получает небольшой буст, чтобы
                                    -- новый контент не тонул
```

`explicit_preferences` берётся из профиля пользователя (интересы, формат
отдыха, сложность, длительность, сезонность и другие заполненные поля).
Пустые поля не штрафуют кандидата. Предпочтения и поведение — разные
сигналы: один просмотр не переписывает профиль.

**Холодный старт** (у пользователя 0 избранного и 0 пропусков): если quiz
заполнен, используем его; остальные веса перераспределяем на
`popularity`/`freshness`, сохраняя разнообразие.

**Контроль перекоса:** поведенческий сигнал вводится с затуханием и cap
(например, не более 25% итогового score). Положительные действия сильнее
просмотра, skip даёт временный cooldown. Финальная колода ограничивает
число маршрутов одной категории/региона и добавляет exploration-слоты для
новых направлений.

**Разнообразие:** после сортировки по `score` — не отдаём топ-N как
есть (иначе колода на день рискует быть одним регионом/категорией).
Простой round-robin по региону при финальной выборке N=15-20 карточек
(соответствует masterplan «конечный список»): берём по одному
маршруту из региона за проход, пока не наберём нужное число.

Это всё вычислимо одним SQL-запросом с CTE + Python-постобработкой
diversity — эмбеддинги/векторный поиск не нужны, что соответствует
ADR-009 («данные раньше семантики»): у нас пока просто нет достаточно
заполненных полей, чтобы семантика окупилась.

## Планировщик: 03:00 МСК = 00:00 UTC

МСК = UTC+3 круглый год (Россия не переходит на летнее время с 2014),
так что это фиксированный сдвиг, не требует таймзонной библиотеки для
пересчёта — `00:00 UTC` **есть** `03:00 МСК`.

В проекте **нет** ни Celery, ни APScheduler, ни какого-либо
планировщика вообще (проверено — `grep -rli "celery\|apscheduler\|cron"`
по `src/` даёт ноль совпадений), и это первая задача, которой
планировщик нужен. Учитывая тесную память прод-хоста (`crimeatrip-test`,
477 МБ RAM всего — см. `production-backend-deploy-runbook.md` и опыт
этой сессии с батчем импорта фото), заводить постоянно живущий процесс
(Celery beat + worker) ради одной задачи в сутки — неоправданный
постоянный расход RAM на демона, который 23 часа 59 минут простаивает.

**Решение: host-level cron, не in-app планировщик.** Тот же паттерн,
что уже отработан в этой сессии для батча импорта фото
(`scripts/import_place_photos.py`, standalone `docker run --rm`,
подключенный к `crimeatrip-test_private`, живёт секунды-минуты,
исчезает) — паттерн этой сессии, нигде раньше не задокументированный,
фиксируем его здесь как шаблон:

```text
# crontab на VPS (не в docker compose):
0 0 * * * docker run --rm \
  --network crimeatrip-test_private \
  --env-file /opt/crimeatrip-test/.env \
  crimeatrip/backend:latest \
  python -m tourism_backend.scripts.generate_route_recommendations
```

Только `_private`-сеть нужна (в отличие от импорта фото) — алгоритм
v1 не ходит во внешние API, только читает/пишет в Postgres.

`scripts/generate_route_recommendations.py` — по образцу
`scripts/import_place_photos.py`: постранично (`--offset`/`--limit`),
чтобы не упереться в память хоста, как это уже случилось с фото при
батчах без пагинации.

**Новые пользователи в течение дня:** у них ещё нет строки в
`route_recommendation_deck_items` на сегодня (батч уже прошёл ночью).
Эндпоинт (ниже) на этот случай считает колоду **лениво** тем же
алгоритмом синхронно при первом запросе за день, если строк для
`(user_id, today)` нет — не ждём следующей ночи.

## API

- `GET /api/v1/routes/recommendations/today` — сегодняшняя (МСК)
  колода пользователя, уже без избранного/недавно пропущенного/уже
  решённого сегодня (решённое сегодня исключается через JOIN на
  `route_recommendation_feedback` и `favorite_routes` с сегодняшней
  датой — то есть сервер, а не клиент, источник истины «что осталось»,
  клиенту не нужно отдельно кешировать «уже смахнутое»).
- `POST /api/v1/routes/{route_id}/recommendation-feedback` — пишет
  `skip` в `route_recommendation_feedback` (`action` allowlist, idempotent
  `client_event_id`). «Favorite» как позитивный сигнал уже покрыт
  существующим `POST /api/v1/favorites/routes/{id}`.

## Мобильная часть (после того как бэкенд готов)

- `routes_providers.dart`: новый провайдер `routeRecommendationsProvider`
  вместо прямого использования `routesListProvider` в
  `RoutesCatalogScreen` (тот остаётся для обычного каталога/поиска).
- `_handleSwipe` в `routes_catalog_screen.dart`: ветка `skip` сейчас
  ничего не делает (см. код, `if (action == RouteSwipeAction.favorite)`
  — `skip` не обработан вообще) — добавить вызов
  `POST .../recommendation-feedback`.
- Кешировать колоду по дате (МСК) локально, чтобы повторный вход в
  экран в тот же день не дёргал сеть — но помнить, что сервер уже сам
  исключает решённое, так что это чисто offline/скорость, не источник
  истины.

## Открытые вопросы (после недели-двух данных)

1. **Длина cooldown на пропуск** — v1 стартует с 14 дней. Может быть
   короче (7) или длиннее (30) — решить эмпирически по
   `route_recommendation_feedback`.
2. **Размер колоды N** — v1 фиксирует 16 карточек/день (диапазон 15–20).
3. **Гостевые пользователи** — API требует auth; гости колоду не получают.
4. **Свайп для мест** — если продукт захочет то же для «Локации»,
   схема переносится почти без изменений
   (`place_recommendation_feedback`/`place_recommendation_deck_items`,
   тот же cron-скрипт двумя проходами) — не проектируем сейчас, но
   таблицы явно параллельны, если понадобится.

## Фазы

| # | Задача | Статус |
| --- | --- | --- |
| 0 | Конечная колода, исключение избранного, экран конца дня (клиент) | ✅ 2026-08-25 |
| 1 | Миграция: `route_recommendation_feedback`, `route_recommendation_deck_items` | ✅ 2026-08-29 |
| 2 | `scripts/generate_route_recommendations.py` + алгоритм v1; host cron ещё не ставим | ✅ скрипт 2026-08-29, cron ops |
| 3 | `GET .../recommendations/today`, `POST .../recommendation-feedback` | ✅ 2026-08-29 |
| 4 | Мобильная часть: провайдер, `skip` шлёт на бэкенд, кеш по дате | план |
| 5 | Разнообразие/веса по реальным данным, пересмотр cooldown/N | план, после недели-двух данных |
