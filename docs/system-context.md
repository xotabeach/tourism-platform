# Системный контекст

Crimea Travel Platform: Flutter-клиент, FastAPI modular monolith, PostGIS,
Redis. Внешний routing — за `RoutingProvider` (Phase 8A). LLM-planner —
за `AIPlanningProvider`: как-built это mock и **LM Studio** (Gemma 4 на
домашней GPU-машине, OpenAI-совместимый HTTP). Стадия hosted Gemini была
запланирована, но пропущена; Ollama-адаптер не писался. Mobile никогда не
ходит в модель напрямую.

Стек по контурам: [stack.md](stack.md).

```mermaid
flowchart LR
    Traveler["Путешественник"]
    Ops["Ops / редактор SQLAdmin"]
    Platform["Crimea Travel Platform"]
    Routing["Routing Provider"]
    LMStudio["LM Studio Gemma 4 home lab"]
    FCM["FCM / APNs"]
    Sources["Внешние источники данных"]

    Traveler -->|Ищет места и планирует поездки| Platform
    Ops -->|Модерация маршрутов, support| Platform
    Platform -->|Distance duration geometry| Routing
    Platform -->|AI planner chat turns| LMStudio
    Platform -.->|tray push| FCM
    Platform -->|Импорт или ручная сверка| Sources
```

Пунктир — не в текущем runtime local/test Compose (кроме FCM, если задан
service account).

## Границы ответственности

Платформа отвечает за:

- учётные записи и пользовательские данные;
- административную географию и каталог мест;
- подготовленные и пользовательские маршруты (модерация);
- происхождение, freshness и публикационный статус контента;
- orchestration построения маршрута и нормализацию ответа provider
  (после Phase 8A);
- validation AI-output до записи маршрута (после Phase 8B).

Платформа не гарантирует безошибочность сторонней маршрутизации и LLM, не
заменяет официальные предупреждения экстренных служб и не является
государственным источником информации. Веса Gemma ≠ база фактов Крыма;
координаты и часы — PostGIS.
