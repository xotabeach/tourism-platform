# ADR-006: AI-assisted route planning

- Статус: принято (архитектурное направление; реализация — Phase 8B+)
- Дата: 2026-07-23

## Контекст

Route Builder должен сначала предлагать editorial routes, а при отсутствии
достаточного match — генерировать private `Route(source=generated)`. Подбор
остановок и интерпретация естественного языка могут выиграть от LLM, но:

- факты о местах (координаты, расписания, цены, закрытия) живут в
  PostgreSQL/PostGIS;
- дорожная геометрия и travel time — зона `RoutingProvider` ([ADR-004](ADR-004-routing-provider-abstraction.md));
- невалидный или «изобретённый» AI output опасен для пользователя.

Нужно зафиксировать границы AI до кода Phase 8B и не смешивать это с Phase 4
editorial catalog.

## Решение

1. **Deterministic Route Builder — источник валидности маршрута.**  
   LLM — опциональный planner/interpreter, не source of truth.
2. **Provider-neutral ports** в application layer (`AIPlanningProvider`,
   `RouteRequestInterpreter`, ToolRegistry и др.). SDK провайдеров только в
   infrastructure adapters.
3. **Stage 1 (Phase 8B):** hosted experimental provider (Gemini adapter),
   structured output, mock provider, feature flag, без production SLA.  
   Model ID — только из configuration/env.
4. **Stage 2 (Future):** self-hosted Gemma-family + RAG; PostGIS остаётся SoT
   для mutable facts; weights не заменяют базу знаний Крыма.
5. **MCP не требуется на старте.** Сначала internal ToolRegistry; MCP —
   будущий transport тех же tools при появлении ≥2 независимых consumers.
6. **Никогда не принимать unvalidated AI output.** Candidate allowlist,
   schema validation, bounded repair, deterministic fallback.
7. Form и Travel+ chat сходятся в **`NormalizedRouteRequest`** и один
   `RouteBuilderPipeline`.

Детали: [ai-route-planning-architecture.md](../ai-route-planning-architecture.md).

## Альтернативы

### Полностью deterministic builder навсегда

Проще и дешевле, но слабее для NL, thematic coherence и clarifications.
Оставляем как default и fallback.

### Fine-tune модели «на все факты о Крыму»

Плохо для mutable facts (часы, закрытия, цены). Отклонено в пользу DB + RAG.

### MCP-first tool layer

Преждевременный operational и security surface. Отложено.

### Отдельный chat generation engine

Дублирование pipeline и расхождение качества. Отклонено.

## Последствия

Положительные:

- ясный rollback на deterministic;
- смена Gemini ↔ Gemma без переписывания domain;
- безопасность через validation и allowlists;
- editorial-first product flow сохранён.

Отрицательные:

- больше интерфейсов и observability;
- стоимость hosted API и позже inference;
- риск prompt injection в UGC/описаниях — нужна гигиена inputs.

## Security

- Untrusted place text в prompts.
- Allowlisted tools, typed args, max tool calls / tokens / candidates.
- No secrets, raw CoT, or full private chat in logs without retention policy.
- Quotas via EntitlementService (Phase 12), не magic numbers в AI adapter.

## Migration path

```text
Phase 8A deterministic
  -> Phase 8B mock + Gemini behind flag
  -> Phase 12 AI quotas / Travel+ policy
  -> Future conversational interpreter
  -> Future Gemma + RAG (+ canary)
  -> Optional MCP adapter
```

Canary Gemini→Gemma: valid JSON rate, hard-constraint compliance, latency,
cost, fallback rate.

## Criteria for revisiting MCP and self-hosting

**MCP:** несколько consumers одних tools; нужен стандартный external tool
protocol; готовы authZ/audit на transport.

**Self-hosting:** стабильный 8B experimental; cost/latency/privacy требуют
on-prem; gold eval проходит на Gemma candidate; ops ready for inference.

## Связь с roadmap

- Phase 4: editorial routes — без AI.
- Phase 8A / 8B / 12 / Future — см. [implementation-plan.md](../implementation-plan.md).
- Progress: AI architecture documented, not implemented —
  [progress.md](../progress.md).
