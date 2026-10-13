# Образ PostgreSQL: локально, CI и прод

BACKEND-45, BACKEND-49. Состояние на 2026-10-13.

## Что где работает

| Где | Образ | Основа | PostGIS | pgvector | glibc (сортировка строк) |
|---|---|---|---|---|---|
| Прод | `crimeatrip/postgis-pgvector:16-3.4`, собран в августе на сервере | Debian bullseye | 3.4.3 | 0.8.6 | 2.31 |
| CI бэкенда | `tourism-backend/docker/ci-postgres` | `pgvector/pgvector:pg16`, Debian bookworm | 3.6 | 0.8.7 | 2.36 |
| Локально | `crimeatrip/postgis-pgvector:16-bookworm` из `docker/postgres` | как в CI | 3.6.4 | 0.8.7 | 2.36 |

PostgreSQL везде 16.15.

## Почему старый образ больше не собирается

`postgis/postgis:16-3.4` построен на Debian bullseye, а pgvector ставился из
репозитория PostgreSQL для bullseye. 2026-10-07 этот репозиторий удалили,
`apt-get update` падает. Прод продолжает работать на уже собранном образе, но
пересобрать его нельзя. Поэтому у базы прода в `deploy/test/compose.yaml` нет
секции `build`: случайный `docker compose build` не подменит базу.

## Переезд прода на новый образ

Делается отдельно, в окно обслуживания, владельцем или с его разрешения.
Данные PostgreSQL 16 переносить не нужно, меняется только образ.

1. Резервная копия: `pg_dump -Fc` базы и копия тома на диск.
2. На сервере собрать новый образ:
   `docker build -t crimeatrip/postgis-pgvector:16-bookworm docker/postgres`.
3. В `.env` прода: `POSTGRES_IMAGE=crimeatrip/postgis-pgvector:16-bookworm`,
   затем `docker compose up -d postgres`.
4. Обновить расширения под новые библиотеки:
   `ALTER EXTENSION postgis UPDATE; ALTER EXTENSION postgis_topology UPDATE;
   ALTER EXTENSION postgis_tiger_geocoder UPDATE; ALTER EXTENSION vector UPDATE;`
5. glibc сменился с 2.31 на 2.36, порядок строк в индексах мог поменяться:
   `REINDEX DATABASE <db>;` затем
   `ALTER DATABASE <db> REFRESH COLLATION VERSION;`
   (то же для `postgres` и `template1`).
6. Проверить `/health`, админку, подбор маршрутов, поиск по смыслу.

Откат: вернуть `POSTGRES_IMAGE=...:16-3.4` и восстановить том из копии, если
после шага 4 уже писались данные.

## Локальная база для тестов

Полный набор тестов бэкенда запускается на временной базе, а не на базе
разработки: `tourism-backend/scripts/test-with-db.sh`. Подробно в README
бэкенда, раздел «Тесты».
