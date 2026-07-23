# Поток генерации маршрута

```mermaid
sequenceDiagram
    actor User as Путешественник
    participant Mobile as Mobile application
    participant API as Route Builder API
    participant Places as Places module
    participant Routes as Routes module
    participant Provider as RoutingProvider
    participant DB as PostgreSQL/PostGIS

    User->>Mobile: Задаёт время, интересы и ограничения
    Mobile->>API: Создать RouteGenerationRequest
    API->>DB: Сохранить нормализованный запрос
    API->>Places: Получить доступные places и entrances
    Places-->>API: Places, schedules, closures, warnings
    API->>Routes: Получить подходящие prepared route data
    Routes-->>API: Кандидаты и editorial constraints
    API->>API: Отфильтровать seasonality, safety и equipment
    API->>Provider: Рассчитать legs между кандидатами

    alt Маршрут рассчитан
        Provider-->>API: Distance, duration, geometry, metadata
        API->>API: Выбрать stops и проверить schedule
        API->>DB: Сохранить GeneratedRoute snapshot
        API-->>Mobile: GeneratedRoute с warnings
        Mobile-->>User: Показать маршрут и ограничения
    else Provider недоступен или путь невозможен
        Provider-->>API: Typed failure
        API->>DB: Сохранить failure status
        API-->>Mobile: Объяснимая ошибка или безопасная альтернатива
        Mobile-->>User: Предложить изменить параметры
    end
```

На первом этапе `RoutingProvider` реализован deterministic stub. Даже после
подключения реального provider финальная проверка closure, schedule, safety,
equipment и freshness остаётся ответственностью платформы.

AI-assisted planning (Phase 8B+) подключается как опциональная
`PlanningStrategy` после editorial miss и выбора candidates: LLM предлагает
ordered place IDs из allowlist, затем снова `RoutingProvider` + deterministic
validation. См. [ai-route-planning-architecture.md](../ai-route-planning-architecture.md)
и [ADR-006](../decisions/ADR-006-ai-assisted-route-planning.md).
