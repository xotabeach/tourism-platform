# ADR-004: RoutingProvider abstraction

- Статус: принято
- Дата: 2026-07-21

## Контекст

Генерация туристического маршрута зависит от расстояний, времени и геометрии
пути. Конкретный внешний provider может иметь ограничения, стоимость,
недоступность, отличающиеся transport modes и лицензионные условия. Legacy
интеграция OpenRouteService не завершена и не должна определять новую
архитектуру.

## Решение

Module `route_builder` определяет application port `RoutingProvider`.
Нормализованный contract принимает waypoints, transport mode и ограничения, а
возвращает legs, distance, duration, geometry, provider metadata и warnings.

Первой реализацией является deterministic stub (`StubRoutingProvider`). Он
поддерживает разработку и тестирование без network или API key. План
self-host OSRM по Крыму и swap stub→OSRM:
[routing-provider-osrm-crimea.md](../routing-provider-osrm-crimea.md).
Реальные adapters не раскрывают provider-specific types за пределами
`infrastructure`.

## Последствия

Положительные:

- route builder разрабатывается до выбора внешнего provider;
- deterministic tests не зависят от сети;
- provider можно заменить или комбинировать;
- ошибки, quotas и metadata нормализуются.

Отрицательные:

- abstraction ограничивает использование уникальных provider features;
- stub не подтверждает качество реальных дорог и travel time;
- adapters требуют contract и integration tests.

## Правила contract

- У каждого запроса есть timeout, correlation ID и typed failure.
- Retry выполняется только для безопасных transient failures.
- Provider response сохраняет attribution и freshness metadata.
- Route safety и доступность не выводятся только из provider geometry.
- Stub явно помечает результат как synthetic и не используется как источник
  production navigation.
