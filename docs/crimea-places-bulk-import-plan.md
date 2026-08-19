# План наполнения PostGIS: 1000+ туристических мест Крыма

Статус: **в работе**, старт 2026-08-19.

Цель — получить в локальном PostGIS минимум 1000 полезных туристических мест
с воспроизводимым источником, корректной географией и честными фильтрами.
Неизвестный факт не подменяется `false`, а импортированный объект не
публикуется до прохождения quality gate.

## Архитектурные правила

1. PostGIS — source of truth для координат, категорий, платности, входов,
   графиков и временных закрытий.
2. OSM/Overpass — источник кандидатов, не автоматическая редакционная истина.
3. Внешний объект имеет стабильный `(source_name, source_external_id)` и
   обновляется идемпотентно.
4. Сырой payload, URL, лицензия и дата проверки сохраняются.
5. Новые OSM-объекты создаются как `publication_status=draft`.
6. Отсутствующий `fee`, `wheelchair`, `dog` означает `unknown`, а не
   бесплатность или доступность.
7. Центр way/relation не выдаётся за реальный вход.
8. Массовая публикация возможна только после проверки границы, дублей,
   категории и обязательных полей.

## Исходное состояние

- PostGIS и GIST-индексы уже есть.
- Seed содержит около 20 мест, 8 населённых пунктов и базовые категории.
- API поддерживал регион, населённый пункт, категорию и поиск по имени.
- `is_paid` не отличал `unknown` от `free`.
- Bulk-команда принимала редакционный JSON, но не знала внешний ID/лицензию.
- При 1000 местах значимые фильтры должны выполняться сервером, не над первыми
  50 записями на телефоне.

## Этап 0 — фундамент импорта

Статус: **реализуется сейчас**.

- [x] Добавить `source_external_id`, `source_license`, `source_payload`.
- [x] Добавить `payment_status=unknown|free|paid`, сохранив `is_paid` для
  обратной совместимости.
- [x] Добавить `data_quality_status`.
- [x] Добавить `recommended_visit_minutes` и `is_suitable_for_pets`.
- [x] Добавить unique partial index по источнику и внешнему ID.
- [x] Расширить серверные фильтры каталога.
- [x] Подготовить pure-нормализатор Overpass и CLI с dry-run.
- [x] Прогнать migration/integration tests на локальном PostGIS.

## Этап 1 — кандидаты OSM

- [x] Обновить локальный seed категорий.
- [x] Получить Overpass JSON по ограниченному tourism/historic/natural
  allowlist.
- [x] Сохранить батчи вне Git в resumable temp cache.
- [x] Выполнить нормализацию с лимитом 1000 и JSON-отчётом.
- [x] Проверить распределение по категориям и причины rejection.
- [ ] Расширять taxonomy только осмысленно; не добавлять магазины, скамейки и
  случайные amenity ради числа.

Импортёр делит запрос по одному selector и использует список публичных
Overpass endpoint с fallback: public instances периодически отвечают 429/5xx.
Список сверяется с <https://wiki.openstreetmap.org/wiki/Overpass_API>.
Успешные батчи кешируются в `/tmp/crimeatrip-overpass-batches`, поэтому после
сетевой ошибки повторный `--fetch` продолжает с незавершённого selector.

Команды из `tourism-backend`:

```bash
# Сеть + отчёт, без записи в БД
uv run python scripts/import_osm_crimea.py \
  --fetch \
  --limit 1000 \
  --output /tmp/crimea-osm-report.json

# Воспроизводимый dry-run из snapshot
uv run python scripts/import_osm_crimea.py \
  --input /path/to/overpass-crimea.json \
  --limit 1000 \
  --output /tmp/crimea-osm-report.json
```

## Этап 2 — локальный PostGIS import

Статус 2026-08-19:

- [x] импортировано 1000 OSM places как `draft/auto_validated`;
- [x] повторный запуск: `created=0`, `updated=1000`;
- [x] `1000` строк имеют `1000` уникальных `source_external_id`;
- [x] `payment_status`: 980 unknown, 10 free, 10 paid;
- [ ] опубликовано после boundary/dedup/editorial gate: пока 0 из OSM.

Локально также остаются 20 опубликованных редакционных seed places. Один
сторонний draft, существовавший до импорта, не изменялся.

Для test/production-контура предусмотрен ручной GitLab job
`backend-deploy-and-import-crimea-production`. Он разворачивает точный образ
коммита, применяет миграции, выполняет сетевой сбор на сервере без постоянного
кеша и печатает контрольную группировку OSM-записей из серверного PostgreSQL.
Импорт также создаёт только `draft/auto_validated`; публикация остаётся
отдельным quality gate.

Серверный результат 2026-08-19 для backend `354a466`:

- собрано 13 647 исходных OSM-объектов;
- принято и создано 1000 мест, `updated=0`;
- SQL: `publication_status=draft`, `data_quality_status=auto_validated`,
  `count=1000`;
- public API по-прежнему показывает только 20 редакционных published places;
- справочник public API содержит 15 категорий.

```bash
cd ../tourism-platform
make init
make up

cd ../tourism-backend
uv sync --all-extras --dev
uv run alembic upgrade head
uv run python scripts/seed_crimea.py

# Запись принятых кандидатов только как draft
uv run python scripts/import_osm_crimea.py \
  --input /path/to/overpass-crimea.json \
  --limit 1000 \
  --apply
```

Проверки после импорта:

```sql
SELECT publication_status, data_quality_status, count(*)
FROM places
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT payment_status, count(*)
FROM places
GROUP BY 1
ORDER BY 1;

SELECT c.code, count(*)
FROM place_categories pc
JOIN categories c ON c.id = pc.category_id
JOIN places p ON p.id = pc.place_id
WHERE p.source_name = 'openstreetmap'
GROUP BY c.code
ORDER BY count(*) DESC;
```

## Этап 3 — граница и дубли

- [ ] Загрузить проверенную границу региона в `regions.boundary`.
- [ ] Отбраковать точки вне `ST_Covers(boundary, location)`.
- [ ] Найти дубли по source ID.
- [ ] Найти вероятные дубли по нормализованному имени и расстоянию 50–150 м.
- [ ] Не объединять автоматически одноимённые места без отчёта.
- [ ] Импортировать реальные entrance nodes, где связь подтверждена.
- [ ] Для way/relation отмечать centroid fallback до появления входа.
- [ ] Расширить localities/границы; не назначать locality только по ближайшему
  центру.

## Этап 4 — фильтры

- [x] категория;
- [x] сложность;
- [x] `payment_status`;
- [x] подходит детям;
- [x] подходит с животными;
- [x] сезон;
- [x] временное закрытие;
- [ ] доступность/коляска;
- [ ] radius/bbox;
- [ ] длительность посещения;
- [ ] открыто в заданный момент — только по подтверждённому расписанию.

Мобильный клиент должен передавать параметры серверу и использовать
pagination/infinite scroll. Фильтрация первых 50 записей на устройстве не
подходит для каталога из 1000 мест.

## Этап 5 — quality gate публикации

Для каждого опубликованного места обязательно:

- координата внутри проверенной границы Крыма;
- пользовательское название;
- минимум одна разрешённая категория;
- уникальный source identity;
- URL и лицензия внешнего источника;
- допустимые enum-значения;
- отсутствие подтверждённого дубля;
- `payment_status=unknown`, если источник не сообщает цену;
- вход отсутствует либо подтверждён — не fake centroid;
- `data_quality_status=editorial_reviewed`.

Целевые метрики:

| Метрика | Цель |
| --- | ---: |
| Структурно валидные кандидаты | >= 1000 |
| Published после проверки | >= 1000 |
| Без source identity | 0 |
| Без категории | 0 |
| За подтверждённой границей | 0 |
| Точные дубли source ID | 0 |
| Unknown-платность, записанная как free | 0 |

Если OSM даёт меньше 1000 качественных мест, подключается второй проверяемый
источник или расширяется осмысленная taxonomy. Низкокачественные объекты не
публикуются только ради счётчика.

## Этап 6 — Route Builder и RAG

- [ ] Заполнить `recommended_visit_minutes` из проверенного источника/правил с
  provenance.
- [ ] Добавить spatial candidate query по радиусу и области.
- [ ] Проверить query plans на 1000/5000/20000 точках.
- [ ] Реализовать deterministic Route Builder Phase 8A.
- [ ] Экспортировать в RAG только опубликованные описания.
- [ ] Не переносить в Qdrant цены, closures и расписания как единственный SoT.

## Definition of done

1. Повторный импорт не создаёт дубли.
2. Локальная БД содержит минимум 1000 проверенных published places.
3. Публичные фильтры выполняются сервером и покрыты integration tests.
4. Spatial containment/radius покрыты тестом на реальном PostGIS.
5. Для источников и лицензий есть отчёт.
6. Route Builder получает только published/non-closed candidates.
7. RAG export не содержит draft/rejected objects.
