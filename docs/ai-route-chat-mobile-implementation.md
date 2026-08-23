# AI-чат подбора и генерация маршрута — план реализации

Статус: **точный контракт будущей реализации**; продуктовый UX (Travel+,
топик-гард, proposal→accept) зафиксирован в
[ai-route-chat-product-contract.md](ai-route-chat-product-contract.md).
Код pipeline ещё не начат; Travel+ gate и mobile topic/crisis guard — as-built.

Экран-референс: `design/screens-figma/krymtrip-2/22-route-match-ai-chat.png`.
Результат: `23-route-match-results.png`. Реализация начинается после
детерминированного Route Builder Phase 8A и стабильного AI provider adapter.

## Главный принцип

```text
Flutter chat -> HTTPS FastAPI -> Route Builder / tools -> PostGIS + routing
                                      |-> Qdrant context
                                      `-> LM Studio Gemma 4
```

Flutter не знает IP LM Studio, model ID, API token, Qdrant или SQL. Даже при
выключенном Windows AI-ПК пользователь получает детерминированный подбор либо
понятную typed-ошибку.

## Пользовательский сценарий

1. Пользователь открывает «Подбор маршрута».
2. Заполняет известные ограничения: дата/сезон, время, старт, транспорт,
   сложность, бюджет, дети/животные, категории.
3. Переходит в AI-чат. Первый системный bubble кратко пересказывает выбранные
   параметры и задаёт только недостающий вопрос.
4. Пользователь отвечает обычным текстом; backend преобразует ответ в
   предложенное изменение typed constraints.
5. Изменения применяются только после валидации; UI показывает их chips.
6. Кнопка «Подобрать маршрут» активируется после минимально достаточных
   параметров.
7. Нажатие создаёт idempotent generation request.
8. UI показывает этапы: подбор мест → проверка ограничений → построение пути →
   готово.
9. Backend возвращает **proposal draft** (ещё не `routes` row).
10. В чате показываются structured blocks: place chips + proposal card +
    действия «Создать маршрут» / «Уточнить» / «Другой вариант».
11. После явного accept создаётся `routes(source=generated)` и открывается
    карточка маршрута. Reject/refine возвращает в чат с теми же constraints.

Детали блоков и топик-гарда:
[ai-route-chat-product-contract.md](ai-route-chat-product-contract.md).

## Кнопка генерации

Состояния:

| Состояние | Поведение |
| --- | --- |
| `disabled_missing_constraints` | выключена, рядом указано что заполнить |
| `ready` | активна, текст «Подобрать маршрут» |
| `submitting` | блок повторного нажатия, локальный progress |
| `generating` | этап backend + cancel, без повторного POST |
| `fallback` | результат построен без AI с объяснением |
| `success` | переход к карточке результата |
| `failure` | typed message + retry с тем же idempotency key |

Кнопка не ждёт свободный текстовый streaming от модели. Backend отдаёт
стабильные доменные progress events, чтобы UI не зависел от формата thinking.

## Предлагаемый API

Пути являются контрактом плана и могут быть уточнены до реализации:

```text
POST   /api/v1/route-builder/sessions
GET    /api/v1/route-builder/sessions
GET    /api/v1/route-builder/sessions/{session_id}
POST   /api/v1/route-builder/sessions/{session_id}/close
GET    /api/v1/route-builder/sessions/{session_id}/messages
POST   /api/v1/route-builder/sessions/{session_id}/messages
PATCH  /api/v1/route-builder/sessions/{session_id}/constraints
POST   /api/v1/route-builder/sessions/{session_id}/generate
GET    /api/v1/route-builder/generations/{request_id}
GET    /api/v1/route-builder/generations/{request_id}/events
POST   /api/v1/route-builder/generations/{request_id}/cancel
```

Сессии и сообщения персистятся в БД (`route_planning_sessions` /
`route_planning_messages`), owner-scoped (BOLA). Список сессий в UI —
следующий срез.

### Открытый вопрос: точка входа «Новый чат» (2026-08-22)

Метод «закрыть текущую сессию + создать новую» реализован на обеих сторонах
(`POST /sessions/{id}/close` + `POST /sessions`; mobile
`_startNewChat()` в `route_match_screen.dart`, проп `onNewChat` у
`RouteAiChatView`). **UI-точки входа сейчас нет.**

Почему: кнопка «Новый чат» стояла над разделителем «Сегодня», но в дизайн-
макетах (`Подбор маршрута 1/2 (тревел +)`) её нет — там сразу шапка →
переключатель режимов → «Сегодня» → первое сообщение. При сверке экранов
1:1 кнопку убрали, чтобы не расходиться с макетом.

Что нужно решить (дизайн + продукт), варианты:

1. Пункт в меню/шите рядом с переключателем режимов (не ломает макет).
2. Свайп-жест или long-press на области чата.
3. Экран истории чатов (`GET /sessions` уже готов) — «Новый чат» логично
   живёт там как первичное действие, а не в самом чате.
4. Вернуть кнопку в чат и обновить макет.

До решения код `_startNewChat` / `onNewChat` **не удалять** — он рабочий,
не хватает только точки входа.

**Решение (2026-08-23):** вариант 3. Отдельный экран истории чатов, точка
входа — в настройках (Профиль → Настройки), не в самом чате. Реализация
отложена (не начата в этом заходе) — сначала фото-пайплайн и карточка
«расскажи о месте» (см. ниже).

`events` — SSE либо обычный polling на первом срезе. WebSocket не нужен, пока
нет доказанной двусторонней realtime-потребности.

### Открытый вопрос: карточка-ответ «расскажи о месте» (2026-08-22)

Пользователь спросил: «можно спросить агента про Ласточкино гнездо и
получить факты + фото + ссылку на страницу места в приложении?» — **частично
реализовано**.

Что уже есть: tool `get_place_details` в `tool_registry.py`
(`_get_place_details`) — модель может запросить структурные факты одного
места по `place_id` (или первому кандидату из `place_candidates`):
категория, платно/бесплатно, время визита, дети/питомцы, транспорт,
сезонность, загруженность, статус закрытия. Модель пересказывает это текстом
в `assistant_text` — сам текстовый Q&A работает.

Чего нет: **отдельного rich-блока с фото и ссылкой на страницу места**.
`get_place_details` не возвращает cover-фото и не создаёт `ChatBlockOut` —
ответ идёт голым текстом, без карточки на подобие `place_chip` (у неё есть
`imageUrl`, но сейчас блок `place_chip` больше не рендерится в чате — см.
пиксель-сверку 2026-08-22) и без диплинка на `/places/{id}` или страницу
маршрута.

Что нужно для полной реализации:

1. Backend: новый `ChatBlockOut` (например `place_info_card`) с
   `place_id`, `title`, `facts` (allowlisted поля из `_get_place_details`),
   `cover_url` (переиспользовать `place_covers.covers_for_places` +
   `generic_fallback_cover`), `deep_link` (маршрут на страницу места в
   приложении, если место опубликовано).
2. `_get_place_details` — дополнить `cover_url`.
3. Mobile: новый блок в `RouteChatMessage` + виджет карточки (фото + факты +
   кнопка «Открыть страницу места», аналогично тому, как проброшен
   `onProposalViewMap` для маршрутов).
4. Промпт модели должен явно предпочитать `get_place_details` вопросам
   «расскажи про X», а не отвечать по памяти (hallucination risk — те же
   facts-only ограничения, что и для маршрутов).

Не реализовывалось в этом заходе — только текстовый Q&A через существующий
tool, без фото/карточки/ссылки. Приоритет и объём — на усмотрение продукта.

Пример typed message response:

```json
{
  "message_id": "uuid",
  "assistant_text": "Предпочитаете прогулку до трёх часов?",
  "proposed_constraints": {
    "duration_minutes_max": 180
  },
  "missing_constraints": ["start_location"],
  "can_generate": false,
  "citations": []
}
```

Пример generation create:

```json
{
  "request_id": "uuid",
  "status": "queued",
  "mode": "ai_with_deterministic_fallback",
  "idempotency_key": "client-generated-uuid"
}
```

## Backend pipeline

1. AuthZ, quota, request-size limit и idempotency.
2. Нормализация `RoutePlanningConstraints`.
3. PostGIS candidate query только по published/non-closed places.
4. Детерминированный scoring Phase 8A.
5. RoutingProvider проверяет достижимость, ETA и геометрию.
6. При включённом AI backend передаёт Gemma allowlist candidate IDs и
   минимальные факты.
7. Опциональный RAG даёт narrative chunks как недоверенные DATA.
8. JSON Schema validation.
9. Проверка неизвестных ID, времени, бюджета, accessibility и safety.
10. Не более одного repair attempt.
11. При timeout/invalid output — deterministic fallback.
12. Persistence generated route и usage metadata без полного приватного
    prompt.

## Минимальная JSON-схема предложения модели

```json
{
  "selected_place_ids": ["uuid"],
  "ordered_place_ids": ["uuid"],
  "explanation": "string",
  "warnings": ["string"],
  "assumptions": ["string"]
}
```

Модель не задаёт координаты, цену, часы и route geometry. Все ID должны быть
из backend allowlist.

## Mobile implementation

Feature-first структура:

```text
lib/features/route_builder/
  data/
    route_builder_api.dart
    route_builder_repository.dart
  domain/
    planning_constraints.dart
    planning_message.dart
    generation_progress.dart
  presentation/
    route_match_chat_screen.dart
    route_match_result_screen.dart
    controllers/route_match_chat_controller.dart
    widgets/constraint_chips.dart
    widgets/generation_button.dart
    widgets/generation_progress.dart
```

Riverpod controller хранит typed state:

```text
initial -> loadingSession -> chatting -> readyToGenerate
        -> generating -> success|fallback|failure
```

Обязательное UX-поведение:

- optimistic bubble допустим только для текста пользователя;
- proposed constraints отображаются отдельно от assistant prose;
- при повторном входе сессия восстанавливается с backend;
- повторный tap не создаёт вторую генерацию;
- cancel прекращает ожидание UI, backend проверяет возможность отмены;
- offline показывает сохранённый draft constraints, но не симулирует AI;
- thinking chain модели пользователю не показывается;
- skeleton используется для карточек результата, но не фальшивые place data.

## Persistence

Планируемые сущности:

- `route_planning_sessions` — owner, constraints, status, timestamps;
- `route_planning_messages` — role, safe text, structured proposal;
- `route_generation_requests` — idempotency, provider, status, failure code;
- существующий `routes(source=generated)` — итоговый маршрут.

Политика retention и возможность удаления AI-сессии фиксируются до
production. Точные GPS traces и секреты в prompt/RAG не сохраняются.

## Typed failure codes

Минимум:

```text
missing_constraints
no_candidate_places
route_not_feasible
ai_unavailable_fallback_used
ai_invalid_output_fallback_used
generation_timeout
quota_exceeded
generation_cancelled
```

Пользователь получает понятный русский текст, лог/метрики — стабильный code.

## Тесты

Backend:

- constraints validation;
- candidate allowlist;
- invalid/unknown model IDs;
- timeout и malformed JSON → fallback;
- idempotent повторный generate;
- quota/authZ/BOLA;
- prompt injection в сообщении и RAG chunk;
- PostGIS/routing integration.

Mobile:

- chat state restoration;
- disabled/ready/loading button states;
- double tap не создаёт второй запрос;
- progress/fallback/error rendering;
- возврат из результата сохраняет session;
- reduced motion и accessibility semantics;
- golden по Figma на целевом viewport.

## Порядок реализации

1. PostGIS-каталог 1000+ мест и серверные фильтры.
2. Phase 8A deterministic Route Builder.
3. `AIPlanningProvider` port + mock + schema validator/fallback.
4. LM Studio OpenAI-compatible adapter.
5. Backend sessions/messages/generation API.
6. Mobile chat и generation button на mock/backend contract.
7. Qdrant RAG ingest/retriever.
8. Gold set, security tests, latency/quality benchmark.
9. Feature flag/canary; только затем production default.

## Definition of done

1. Mobile общается только с backend.
2. Кнопка имеет все typed states и защищена idempotency.
3. Выключенный AI-ПК не ломает основной подбор.
4. Модель не может выбрать неизвестное место или выполнить SQL/tool сама.
5. Результат проходит domain validation и RoutingProvider.
6. Ошибки и fallback понятны пользователю.
7. Figma golden, integration и security tests зелёные.
