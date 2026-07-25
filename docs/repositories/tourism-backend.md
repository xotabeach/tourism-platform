# Профиль репозитория tourism-backend

## Назначение

`tourism-backend` — отдельный будущий репозиторий серверной реализации.
Именно в нём с первого server iteration развивается modular monolith. После
создания private remote он клонируется рядом с `tourism-platform` как
Git submodule общего superproject.

## Ответственность

- Содержать серверное приложение и domain modules.
- Предоставлять версионируемые программные интерфейсы.
- Управлять прикладными миграциями PostgreSQL и PostGIS.
- Интегрироваться с Redis и внешними поставщиками через адаптеры.
- Обеспечивать фоновые операции, аудит и эксплуатационную диагностику.
- Определять transport-neutral application и integration event contracts.
- Соблюдать границы владения данными между доменами.

## Вне целей

- Преждевременное разделение модулей на сетевые микросервисы.
- Хранение мобильного приложения и деклараций инфраструктуры.
- Прямой импорт чужих ORM-моделей между доменами.
- Владение картографическими или медиа-системами внешних поставщиков.
- Создание удалённого репозитория в рамках этого профиля.

## Будущая реализация и стек

- Python 3.13, FastAPI и Pydantic v2.
- SQLAlchemy 2, Alembic, PostgreSQL и PostGIS.
- `uv`, Ruff, MyPy и Pytest.
- Redis для кеширования, ограничений и краткоживущей координации.
- Celery или Dramatiq только после появления реальных background tasks.
- Kafka как planned integration event transport только после активации
  ADR-005.
- Transactional Outbox и idempotent consumers для надёжной event delivery.
- OpenAPI, structured JSON logs, health check и readiness check.
- Configuration через environment variables без secrets в repository.
- Контейнерные сборки и автоматизированные проверки.

## Интеграции

- `tourism-mobile` через публичные контракты.
- `tourism-infrastructure` через соглашения о конфигурации и выпуске.
- `tourism-documentation` как источник архитектурных решений.
- PostgreSQL, PostGIS и Redis как управляемые зависимости среды.
- Kafka через infrastructure adapter; domain layer не импортирует Kafka SDK.
- Картографические, геокодинговые и объектные хранилища через порты.

## Результаты

- Воспроизводимая серверная сборка.
- Документированный и версионируемый программный интерфейс.
- Миграции и процедуры восстановления.
- Автоматические модульные, интеграционные и контрактные проверки.
- Панели наблюдаемости и эксплуатационные инструкции.

## Поэтапный план

### Этап 1. Foundation

- [x] Создать private remote и добавить repository как submodule.
- [x] Создать Python 3.13 project через `uv`.
- [x] Зафиксировать domain boundaries и dependency rules.
- [x] Настроить FastAPI, configuration, logs и health endpoints.

### Этап 2. Data и contracts

- [x] Подключить SQLAlchemy, Alembic и PostGIS.
- [ ] Реализовать первые modules без cross-domain ORM imports.
- [ ] Опубликовать OpenAPI contract.
- [x] Настроить Ruff, MyPy и Pytest.
- [x] Добавить security regressions, `pip-audit` и fail-closed CI integration
  gate.

### Этап 3. MVP

- [ ] Реализовать modules в согласованном порядке.
- [ ] Добавить deterministic `RoutingProvider` stub.
- [ ] Проверить сквозные сценарии с мобильным клиентом.

### Этап 4. Эксплуатация

- [ ] Определить показатели доступности и задержки.
- [ ] Настроить резервное копирование и учения по восстановлению.
- [ ] Включить аудит административных и чувствительных операций.
- [ ] Реализовать outbox только для подтверждённого asynchronous flow.
- [ ] Добавить schema compatibility и consumer contract tests до Kafka.
- [ ] Оценивать извлечение доменных модулей только по утверждённым
  критериям.
