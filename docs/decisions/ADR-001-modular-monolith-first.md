# ADR-001: Modular monolith на первом этапе

- Статус: принято
- Дата: 2026-07-21

## Контекст

Платформе нужны отдельные бизнес-границы, но раннее разделение на network
services увеличит стоимость разработки, локального запуска, транзакций,
наблюдаемости и изменения contracts. Команда создаёт greenfield MVP и ещё не
имеет подтверждённых требований к независимому масштабированию domains.

## Решение

Backend реализуется как modular monolith с boundaries. На 2026-08-26
модулей 14 (список ниже — исходный набор решения плюс появившиеся позже):

- `identity`;
- `users`;
- `geography`;
- `places`;
- `routes`;
- `route_builder`;
- `media`;
- `admin`, `favorites`, `knowledge`, `notifications`, `route_execution`,
  `subscriptions`, `support` — добавлены после принятия ADR.

Внутри каждого module применяется pragmatic clean architecture со слоями
`domain`, `application`, `infrastructure`, `presentation`. Module владеет своей
persistence model. Cross-domain ORM imports и navigation properties запрещены;
интеграция выполняется через IDs, application contracts и domain events.

> **Фактическое отклонение (2026-08-26).** Правило не соблюдается: 62 прямых
> импорта чужих `infrastructure.models` из `*/application/*.py`, плотнее
> всего в `route_builder` (~22), `places` (~11), `routes` (~9), `identity`
> (~8). Автоматических dependency tests, которых требует раздел
> «Последствия», нет — правило держится только на review и на практике не
> удержалось. Решение (монолит как единица деплоя) при этом в силе; см.
> [reviews/2026-08-25-review-remediation-plan.md](../reviews/2026-08-25-review-remediation-plan.md)
> фаза 8 — постепенная чистка + dependency test, чтобы не регрессировало.

## Последствия

Положительные:

- один deployable unit и простой local development;
- локальные транзакции там, где они действительно нужны;
- явные domain boundaries без преждевременной distributed complexity;
- возможность извлечь module при доказанной необходимости.

Отрицательные:

- ошибка process-level может затронуть весь backend;
- независимое масштабирование modules недоступно;
- архитектурные границы требуют автоматических dependency tests и review.

## Критерии пересмотра

Module рассматривается для выделения в service, если подтверждены независимое
масштабирование, отдельный lifecycle, требования изоляции, ownership отдельной
команды или эксплуатационная необходимость. Сам размер codebase не является
достаточной причиной.
