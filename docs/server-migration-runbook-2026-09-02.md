# Runbook: переезд на новый сервер

**Дата:** 2026-09-02
**Откуда:** `crimeatrip-test`, 86.106.20.132, 477МБ RAM
**Куда:** `crimeatrip-prod`, 201.24.55.130, Ubuntu 26.04, 8ГБ RAM / 4 ядра / 77ГБ SSD, Москва
**Статус: ВЫПОЛНЕНО 2026-09-02.** Фактический ход и расхождения с планом — в §11.

Порядок шагов важен: всё, что можно сделать **до** остановки сервиса, вынесено в
подготовку, чтобы окно простоя было минимальным (реально — минуты, объём данных
маленький).

---

## 0. За сутки до переезда (если возможно) — TTL у DNS

**Сделать первым, до всего остального.** Понизить TTL A-записи `API_HOST` до 300 секунд.
Если TTL сейчас 3600+, то после переключения часть клиентов ещё час будет ходить на
старый сервер. Старый сервер поэтому не гасим сразу (см. §9).

Если переезд делается сегодня и TTL понизить заранее не успели — это не блокер, просто
хвост переключения будет длиннее, и старый контур должен продолжать отвечать всё это
время.

---

## 1. Что именно переезжает

Проверено по `deploy/test/compose.yaml` и runbook'у, ничего «на память»:

| Что | Где сейчас | Критичность |
| --- | --- | --- |
| Том `postgres-data` | docker volume `crimeatrip-test_postgres-data` | **Критично.** Вся БД |
| Том `media-data` | docker volume `crimeatrip-test_media-data` | **Критично.** 153МБ / 629 файлов, пользовательские фото |
| Тома `caddy-data`, `caddy-config` | docker volumes | Желательно — там ACME-аккаунт и выпущенные сертификаты |
| `.env` | `/opt/crimeatrip-test/.env`, режим 600 | **Критично.** Все секреты |
| `compose.yaml`, `Caddyfile` | `/opt/crimeatrip-test/` | Из гита, копировать не надо |
| Чекаут платформы | `/opt/crimeatrip-platform` | Из гита |
| Обёртка ретенции | `/opt/crimeatrip-test/run-route-snapshot-retention.sh` | Из гита (`tourism-platform/scripts/`) |
| Хостовый cron | `crontab` пользователя деплоя | Переставить руками, см. §7 |
| Образы контейнеров | GitLab Container Registry | **Не переносим** — тянутся заново |
| CI-переменные | GitLab protected variables | Обновить, см. §8 |

**Решение по именованию:** проект в compose называется `crimeatrip-test`, и от этого имени
зависят имена томов. На переезде **имя не меняем** — переименование в `crimeatrip-prod`
делается отдельной задачей потом. Иначе к обычным рискам переезда добавляется целый класс
ошибок «восстановили не в тот том».

---

## 2. Подготовка нового сервера (сервис ещё работает на старом)

```bash
# 2.1 Пользователь для деплоя, без пароля, только по ключу
adduser --disabled-password --gecos "" deploy
usermod -aG docker deploy
mkdir -p /home/deploy/.ssh && chmod 700 /home/deploy/.ssh
# положить сюда публичные ключи: свой + CI-шный
chown -R deploy:deploy /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys

# 2.2 SSH: только ключи
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload ssh

# 2.3 Файрвол
ufw default deny incoming && ufw default allow outgoing
ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp
ufw --force enable

# 2.4 Docker + compose-плагин (официальный репозиторий, не snap)
curl -fsSL https://get.docker.com | sh

# 2.5 Каталоги
mkdir -p /opt/crimeatrip-test /opt/crimeatrip-platform /opt/backups
chown -R deploy:deploy /opt/crimeatrip-test /opt/crimeatrip-platform /opt/backups
```

Дальше — под пользователем `deploy`:

```bash
git clone <platform-repo> /opt/crimeatrip-platform
cp /opt/crimeatrip-platform/deploy/test/{compose.yaml,Caddyfile} /opt/crimeatrip-test/
cp /opt/crimeatrip-platform/scripts/run-route-snapshot-retention.sh /opt/crimeatrip-test/
chmod +x /opt/crimeatrip-test/run-route-snapshot-retention.sh
docker login registry.gitlab.com   # deploy-token, не личный пароль
```

**Сертификаты пока не выпускаем** — DNS ещё смотрит на старый сервер, ACME не пройдёт.

---

## 3. Снятие данных со старого сервера

Бэкенд останавливаем, постгрес оставляем — так гарантируется, что во время дампа никто
не пишет. **Отсюда начинается окно простоя.**

```bash
# На СТАРОМ сервере
cd /opt/crimeatrip-test
export COMPOSE="docker compose --env-file .env --file compose.yaml"

# 3.1 Остановить только приём трафика и запись
$COMPOSE stop caddy backend

# 3.2 Логический дамп БД
source .env
docker exec crimeatrip-test-postgres-1 \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom \
  > /tmp/crimeatrip-$(date +%F).dump

# 3.3 Контрольные цифры ДО переезда — записать, они понадобятся в §6
docker exec crimeatrip-test-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
  SELECT 'routes' t, count(*) FROM routes
  UNION ALL SELECT 'places', count(*) FROM places
  UNION ALL SELECT 'users', count(*) FROM users
  UNION ALL SELECT 'articles', count(*) FROM articles
  UNION ALL SELECT 'media_attachments', count(*) FROM media_attachments
  UNION ALL SELECT 'knowledge_chunks', count(*) FROM knowledge_chunks;"

docker exec crimeatrip-test-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT version_num FROM alembic_version;"

# 3.4 Тома media и caddy — тарим через одноразовый контейнер
for v in media-data caddy-data caddy-config; do
  docker run --rm -v "crimeatrip-test_${v}:/data:ro" -v /tmp:/out alpine:3.21 \
    tar czf "/out/${v}.tar.gz" -C /data .
done

# 3.5 Число файлов медиа — вторая контрольная цифра
docker run --rm -v crimeatrip-test_media-data:/data:ro alpine:3.21 \
  sh -c 'find /data -type f | wc -l'

# 3.6 Контрольные суммы
cd /tmp && sha256sum crimeatrip-*.dump *.tar.gz > checksums.txt && cat checksums.txt
```

Копирование на новый сервер — **напрямую между серверами, не через ноутбук**:

```bash
scp -3 deploy@OLD:/tmp/{crimeatrip-*.dump,media-data.tar.gz,caddy-data.tar.gz,caddy-config.tar.gz,checksums.txt} \
      deploy@NEW:/tmp/
# либо, если между серверами есть прямой доступ:
#   ssh deploy@OLD 'cat /tmp/media-data.tar.gz' | ssh deploy@NEW 'cat > /tmp/media-data.tar.gz'
```

На новом сервере **обязательно** сверить:

```bash
cd /tmp && sha256sum -c checksums.txt
```

---

## 4. `.env` — переносим руками, с правками

Скопировать `/opt/crimeatrip-test/.env` со старого сервера и **сохранить как есть**
`JWT_SIGNING_KEY`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `ADMIN_SESSION_SECRET`. Если
поменять `JWT_SIGNING_KEY` — **у всех пользователей разлогинится приложение**; на переезде
это лишняя переменная, меняем ключи потом и осознанно.

Что поменять сразу:

```bash
chmod 600 /opt/crimeatrip-test/.env   # deploy-remote.sh откажется работать без 600
```

- `BACKEND_IMAGE` — оставить тот же тег, что крутится сейчас на старом сервере
  (`docker inspect --format='{{.Config.Image}}' crimeatrip-test-backend-1`);
- **`GEMINI_BASE_URL`** — новый сервер в Москве, прямой доступ к
  `generativelanguage.googleapis.com` не работает. Либо указать на релей, либо
  переключить `AI_PROVIDER` (подробно — в
  [articles-mobile-rating-context-rag-backlog-2026-09-01.md](articles-mobile-rating-context-rag-backlog-2026-09-01.md),
  §4.0/§4.1 и обсуждение провайдеров). **Проверить это до переключения DNS**, иначе ИИ-чат
  тихо ляжет уже на новом контуре.

---

## 5. Восстановление на новом сервере

```bash
cd /opt/crimeatrip-test
export COMPOSE="docker compose --env-file .env --file compose.yaml"
source .env

# 5.1 Только БД и Redis
$COMPOSE up --detach postgres redis
# дождаться healthy
docker inspect -f '{{.State.Health.Status}}' crimeatrip-test-postgres-1

# 5.2 Восстановить дамп. Схема приезжает вместе с ним —
#     alembic ДО восстановления не запускать.
docker cp /tmp/crimeatrip-*.dump crimeatrip-test-postgres-1:/tmp/db.dump
docker exec crimeatrip-test-postgres-1 \
  pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges /tmp/db.dump
docker exec crimeatrip-test-postgres-1 rm /tmp/db.dump

# 5.3 Тома
for v in media-data caddy-data caddy-config; do
  docker volume create "crimeatrip-test_${v}"
  docker run --rm -v "crimeatrip-test_${v}:/data" -v /tmp:/in alpine:3.21 \
    tar xzf "/in/${v}.tar.gz" -C /data
done

# 5.4 Владелец медиа — appuser (uid 10001), иначе загрузка фото упадёт.
#     Ровно то же делает deploy-remote.sh.
docker run --rm -v crimeatrip-test_media-data:/data alpine:3.21 chown -R 10001:10001 /data

# 5.5 Догнать миграции (должно быть no-op, если образ тот же)
$COMPOSE --profile tools run --rm migrate

# 5.6 Поднять всё
$COMPOSE up --detach
```

---

## 6. Проверка до переключения DNS

Пока DNS смотрит на старый сервер, новый проверяем в обход:

```bash
# 6.1 Бэкенд здоров (изнутри сервера, мимо Caddy)
docker exec crimeatrip-test-backend-1 \
  python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health/ready').read())"

# 6.2 Те же контрольные цифры, что в §3.3 — должны совпасть ВСЕ
docker exec crimeatrip-test-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
  SELECT 'routes' t, count(*) FROM routes
  UNION ALL SELECT 'places', count(*) FROM places
  UNION ALL SELECT 'users', count(*) FROM users
  UNION ALL SELECT 'articles', count(*) FROM articles
  UNION ALL SELECT 'media_attachments', count(*) FROM media_attachments
  UNION ALL SELECT 'knowledge_chunks', count(*) FROM knowledge_chunks;"

# 6.3 Версия миграций совпадает с §3.3
docker exec crimeatrip-test-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT version_num FROM alembic_version;"

# 6.4 Файлы медиа на месте — число должно совпасть с §3.5
docker run --rm -v crimeatrip-test_media-data:/data:ro alpine:3.21 \
  sh -c 'find /data -type f | wc -l'

# 6.5 PostGIS и pgvector живы (образ тот же, но проверить дёшево)
docker exec crimeatrip-test-postgres-1 psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT extname FROM pg_extension WHERE extname IN ('postgis','vector');"
```

С ноутбука — проверка HTTPS до переключения DNS, подменой резолва:

```bash
curl -fsS --resolve "$API_HOST:443:<NEW_IP>" "https://$API_HOST/health/ready"
```

**Переключать DNS только когда все шесть проверок прошли.**

---

## 7. Cron на новом сервере

Ставится от пользователя `deploy` (`crontab -e`). Ретенция — из существующего runbook'а,
остальное — то, что на старом сервере не помещалось:

```cron
# Ретенция снапшотов маршрутов — 03:20 MSK
20 0 * * * RETENTION_DEPLOY_DIR=/opt/crimeatrip-test \
  RETENTION_ENV_FILE=/opt/crimeatrip-test/.env \
  /opt/crimeatrip-test/run-route-snapshot-retention.sh \
  >>/var/log/crimeatrip-retention.log 2>&1

# Ежедневные колоды рекомендаций (профиль maintenance, внешних API не зовёт)
40 0 * * * cd /opt/crimeatrip-test && docker compose --env-file .env --file compose.yaml \
  --profile maintenance run --rm recommendations >>/var/log/crimeatrip-recs.log 2>&1

# Бэкап БД — то, ради чего ждали переезда (db-backups-plan-new-server.md)
0 2 * * * cd /opt/crimeatrip-test && docker compose --env-file .env --file compose.yaml \
  exec -T postgres pg_dump -U tourism_app -d tourism_test --format=custom \
  > /opt/backups/db-$(date +\%F).dump 2>>/var/log/crimeatrip-backup.log

# Чистка образов — на старом сервере уже был инцидент "No space left on device"
30 3 * * 0 docker image prune -af --filter "until=168h" >/dev/null 2>&1
```

**Важно из `db-backups-plan-new-server.md`:** дампы в `/opt/backups` — это только половина
дела, они лежат на том же диске, что и БД. Настроить выгрузку наружу (S3-совместимое
хранилище или второй сервер) — **иначе бэкапы не защищают от потери диска**. Это первое,
что надо доделать после переезда.

---

## 8. GitLab CI

Обновить protected-переменные (имена — из `tourism-backend/scripts/ci-deploy-production.sh`):

- `DEPLOY_SSH_HOST` → новый IP/хост;
- `DEPLOY_SSH_PORT`, `DEPLOY_SSH_USER` → если менялись;
- `DEPLOY_SSH_KNOWN_HOSTS` → **обязательно перевыпустить**: `ssh-keyscan -p <port> <new-host>`.
  Старый ключ хоста не подойдёт, и деплой упадёт на пиннинге — это ожидаемое поведение,
  не баг;
- `DEPLOY_SSH_PRIVATE_KEY` → если завели новую пару.

После этого прогнать деплой из CI на новый сервер **до** гашения старого — так проверяется,
что автоматический путь работает, а не только ручной.

---

## 9. Гашение старого сервера

**Не сразу.** Держать включённым минимум:

- пока не истечёт старый TTL DNS + запас (сутки, если TTL был часовой);
- пока не пройдёт хотя бы один успешный CI-деплой на новый сервер;
- пока не отработает первый ночной бэкап на новом.

Пока старый жив, у него есть ещё одна роль: **он находится вне РФ, поэтому может временно
служить релеем для Gemini** (см. §4). Если пойдём этим путём — гасить его нельзя до
переключения на доступного из РФ провайдера. Назначить дату, иначе «временный прокси»
останется навсегда.

---

## 10. Что настроить уже ПОСЛЕ переезда (ради чего он и делался)

Отдельными изменениями, не в окне простоя:

1. **Лимиты в `compose.yaml`.** Сейчас: caddy 48М, backend 192М, postgres 224М, redis 48М
   — сумма 512М на коробке с 477М. Целевой бюджет на 8ГБ: postgres 2Г, backend 1.5Г,
   redis 256М, caddy 128М, ~1Г резерв под локальный эмбеддер, ~3Г свободно.
2. **Тюнинг Postgres.** Сейчас `shared_buffers=32MB`, `work_mem=1MB`,
   `effective_cache_size=128MB`, `max_connections=20`. Цель: `shared_buffers` 1–2Г,
   `work_mem` 16М, `effective_cache_size` 4Г, `maintenance_work_mem` 256М,
   `max_connections` 50.
3. **`--workers` у uvicorn.** В `Dockerfile:43` воркер один, то есть из 4 ядер
   используется одно.
4. **WAL-архивация / `archive_mode=on`** — на 477М не помещалась, теперь можно. Даёт PITR,
   а не только «на момент последнего дампа».
5. **Выгрузка бэкапов за пределы сервера** (см. §7).
6. **Провайдер ИИ** — постоянное решение вместо релея.
7. Локальный эмбеддер для RAG — §4.1 бэклога, ради него в бюджете памяти оставлен 1Г.

Каждый пункт — отдельный коммит и отдельная проверка. Не тащить их в окно переезда:
переезд должен быть переездом, а не переездом с рефакторингом.


---

# 11. Что реально произошло (заполнено по факту, 2026-09-02)

Переезд выполнен. Простой — **около минуты** (только окно снятия дампа). Ниже то, в чём
реальность разошлась с планом выше: план оставлен как был, чтобы расхождения были видны.

## 11.1 DNS переключать было нечего — и это меняет схему

`API_HOST` — это `86-106-20-132.sslip.io`. **sslip.io кодирует IP прямо в имени**, то есть
A-записи, которую можно переключить, не существует. Хуже: адрес зашивается в APK при
сборке (`build-signed-apk.sh:26` → `--dart-define=API_BASE_URL`).

Следствие: §0 (понижение TTL) и §9 (ожидание истечения TTL) — **неприменимы**. Вместо
переключения оба сервера работают параллельно на разных именах:

- старый `86-106-20-132.sslip.io` — обслуживает **уже установленные** APK;
- новый `201-24-55-130.sslip.io` — заработает для приложения только после пересборки APK.

**Открытое следствие, требующее решения:** с момента снятия дампа (2026-09-02 12:05 UTC)
**две базы расходятся**. Всё, что пользователи пишут через установленные APK, попадает
только на старый сервер. Перед сменой адреса в сборке нужно либо повторно синхронизировать
БД, либо осознанно принять потерю этой дельты. Пользователь покупает домен на этой неделе —
после чего эта проблема исчезает навсегда, но **дельту всё равно надо будет закрыть**.

## 11.2 Гео-блок Gemini подтверждён, но диагностируется неочевидно

Первая проверка (`curl` без ключа) дала 403 и выглядела как блок — на самом деле это
«нет ключа». С ключом ответ другой и однозначный:

```
400 FAILED_PRECONDITION: "User location is not supported for the API use."
```

**Ловушка:** `provider.probe()` при этом возвращает `{"status":"ok","language":"ru"}` и
выглядит как успех. Это синтетический `fallback_structured_turn`, а не ответ Google.
**Не использовать `probe()` как проверку связности** — только прямой HTTP-запрос с ключом.

## 11.3 Найденный дефект: `GEMINI_BASE_URL` не доезжал до контейнера

Переменная есть в `config.py:110`, но **отсутствовала в блоке `x-backend-environment`**
в `compose.yaml`. То есть значение из `.env` игнорировалось, приложение молча брало дефолт
(прямой Google) — настройка релея была бы мёртвой. Добавлено на сервере:

```yaml
GEMINI_BASE_URL: ${GEMINI_BASE_URL:-https://generativelanguage.googleapis.com/v1beta}
```

**Это нужно закоммитить в репозиторий** — см. §11.5.

## 11.4 Релей

Отдельный сайт в существующем Caddy на **старом** сервере (не отдельный контейнер: ACME
уже настроен на 80/443):

```
relay.{$API_HOST} → reverse_proxy https://generativelanguage.googleapis.com
```

Доступ ограничен `@allowed remote_ip 201.24.55.130` — иначе это открытый прокси в
интернет. Проверено: с нового сервера отдаёт 200 и 50 моделей; с любого другого IP — 403.

`admin off` в Caddyfile means `caddy reload` через API не работает — нужен
`docker compose restart caddy` (перерыв ~1–2 с).

**Пока релей жив, старый сервер гасить нельзя.**

## 11.5 Репозиторий отстал от сервера — надо закоммитить

`deploy/test/compose.yaml` в гите **не содержит** блока переменных ИИ, который живёт на
сервере с 2026-08-31 (`AI_PLANNING_ENABLED`, `AI_PROVIDER`, `AI_REQUEST_TIMEOUT_SECONDS`,
`AI_MAX_REPAIR_ATTEMPTS`, `GEMINI_API_KEY`, `TSP_PROVIDER`, `DISTANCE_MATRIX_PROVIDER`)
плюс добавленный сегодня `GEMINI_BASE_URL`. При деплое из чистого чекаута конфигурация ИИ
была бы потеряна. Актуальная версия — на новом сервере в `/opt/crimeatrip-test/compose.yaml`.

## 11.6 Чего не было в плане, но пришлось переносить

- **`secrets/fcm-service-account.json`** — ключ FCM, монтируется через
  `FCM_SERVICE_ACCOUNT_FILE`. В §1 его не было; перенесён, режим 600, владелец root.
- **`run-recommendation-decks.sh`** — обёртка для колод уже существовала на сервере;
  использована она, а не сырая строка `docker compose` из §7.
- **Образы**: `crimeatrip/postgis-pgvector:16-3.4` собран локально и **отсутствует в
  реестре**, а бэкенд-образ требует логина в GitLab. Оба перенесены напрямую
  `docker save | ssh | docker load` — так гарантированно те же биты, что в проде, и не
  нужны учётные данные реестра на новом сервере.
- **Пользователь деплоя** называется `crimeatrip-deploy`, а не `deploy`.
- `patches/` на старом сервере (`fcm.py`, `lm_studio.py`) — остатки ручных хотфиксов,
  **никуда не смонтированы** (проверено диффом compose), не переносились.

## 11.7 Восстановление БД: подвох с PostGIS

`pg_restore` в свежесозданную образом БД падает на `schema "tiger" already exists` —
инициализация PostGIS-образа создаёт `tiger`/`topology`, и они же есть в дампе.
**Правильный порядок:** `DROP DATABASE` → `CREATE DATABASE` → `pg_restore` (дамп содержит
и схемы, и `CREATE EXTENSION`). Проверено: `postgis` и `vector` на месте.

## 11.8 Сверка после переезда — сошлось всё

| | Было | Стало |
| --- | --- | --- |
| routes / route_stops | 35 / 85 | 35 / 85 |
| places | 5020 | 5020 |
| users | 12 | 12 |
| articles | 0 | 0 |
| media_attachments | 265 | 265 |
| knowledge_chunks | 72 | 72 |
| route_reviews | 4 | 4 |
| alembic_version | `0048_articles` | `0048_articles` |
| файлов медиа | 250 (161.8M) | 250 (161.8M) |

Плюс: `/api/v1/routes` и `/api/v1/places` дают одинаковые ответы на обоих серверах,
картинка отдаётся байт-в-байт (846780 байт), сертификат для нового хоста выпущен.

**Отдельно:** цепочка откатов Gemini (`gemini_model_unavailable_falling_back` ×3)
воспроизводится **одинаково на обоих серверах** — это предсуществующее поведение (похоже,
исчерпанная квота бесплатного ключа), а не следствие переезда.

## 11.9 Что сделано сверх плана

- Ежедневный бэкап БД (`run-db-backup.sh`, 7 копий, 05:00 MSK) — то, чего ждали от
  переезда. **Первый дамп снят и лежит в `/opt/backups`.**
- Кроны ретенции и колод перенесены 1:1.
- Еженедельная чистка образов.

## 11.10 Осталось (не в окне переезда)

1. **Закрыть дельту двух БД** и пересобрать APK — см. §11.1.
2. **Закоммитить `compose.yaml`** в репозиторий — §11.5.
3. **Выгрузка бэкапов за пределы сервера** — сейчас они на том же диске, что и БД.
4. **Порты 25/465/587/2525 закрыты провайдером** → `MAILTO` в cron работать не будет,
   нужен другой канал алертов (сейчас скрипты пишут в syslog через `logger`).
5. Тюнинг Postgres, `--workers` у uvicorn, лимиты памяти — §10.
6. Постоянный провайдер ИИ вместо релея.

---

# 12. Старый сервер после вывода приложения (2026-09-02, вечер)

Решение пользователя: приложение целиком живёт на новом сервере, старые APK не
поддерживаем (удаляются с телефонов вручную). На старом сервере остаётся **только релей
Gemini**.

## 12.1 Что сделано

- Финальная сверка: базы были **идентичны** (12 users / 35 routes / 5020 places /
  6 executions / 265 media, последняя запись `2026-09-01 09:42:35` на обоих). Дельты,
  которой опасались в §11.1, не возникло — приложением с 1 сентября не пользовались.
- Финальный дамп со старого сервера лежит на новом:
  `/opt/backups/db-FINAL-from-old-server-20260902.dump` (sha256 сверен после копирования).
- Кроны приложения на старом сервере сняты, бэкап — `/root/crontab.backup.20260902`.
- Стек `crimeatrip-test` остановлен через `down` **без `-v`**: тома
  `postgres-data`, `media-data`, `caddy-data`, `caddy-config` намеренно оставлены на
  диске как страховка. Удалять их — отдельное осознанное решение, не раньше чем через
  пару недель работы нового контура.
- Поднят отдельный compose-проект `/opt/gemini-relay` (только Caddy, `mem_limit: 64m`),
  переиспользующий том `crimeatrip-test_caddy-data` — сертификат для `relay.*` уже в нём,
  повторный выпуск через ACME не нужен.

## 12.2 Что на старом сервере трогать нельзя

**`instagram-telegram-bot.service`** — сторонний проект пользователя:
`/opt/instagram-downloader`, systemd-юнит, python из venv, **не Docker**. Операции с
контейнерами его не задевают, но при любой уборке на этом хосте про него надо помнить.

## 12.3 Проверено после переключения

| Проверка | Результат |
| --- | --- |
| Релей с нового сервера | HTTP 200, 50 моделей |
| Релей из контейнера бэкенда (`gemini_base_url`) | HTTP 200, 50 моделей |
| Старый API `https://86-106-20-132.sslip.io/health/ready` | не отвечает (ожидаемо) |
| `instagram-telegram-bot.service` | `active` |
| Контейнеры на старом сервере | только `gemini-relay-caddy-1` |
| Новый API | `{"status":"ready"}` |

Память на старом сервере: было ~254МБ занято, стало ~193МБ из 477МБ.

## 12.4 GitLab Runner на новом сервере

Ставится, чтобы не упираться в лимиты минут на gitlab.com. `gitlab-runner` 19.3.1
установлен, `concurrent = 1`.

**Осознанный компромисс:** раннер живёт на одном хосте с продом. Сборка, выевшая память
или забившая диск, задевает API. Отсюда `concurrent = 1` и обязательная еженедельная
чистка образов (уже в кроне). Если сборки начнут мешать — выносить на отдельный хост,
это дешевле, чем отлаживать деградацию прода.

**Зарегистрирован 2026-09-02** групповым раннером `travel-platform2`, имя
`crimeatrip-prod`, id 55828564. Один раннер обслуживает все четыре репозитория.
Запускается systemd (`ExecStart=/usr/bin/gitlab-runner run …`), юнит `enabled`, так что
переживает перезагрузку — вручную `gitlab-runner run` дёргать не нужно.

Итоговый `/etc/gitlab-runner/config.toml`:

| Параметр | Значение | Зачем |
| --- | --- | --- |
| `concurrent` | `1` | одна сборка за раз, чтобы не конкурировать с Postgres |
| `memory` / `memory_swap` | `2g` / `2g` | потолок сборки; у хоста 8ГБ, ~5ГБ расписано под приложение |
| `cpus` | `2` | из четырёх ядер |
| `shm_size` | `67108864` | 64МБ, дефолтных 64КБ не хватает многим сборкам |
| `privileged` | `true` | требуется для `services: docker:27-dind` в `.gitlab-ci.yml` |
| `volumes` | `["/certs/client", "/cache"]` | **сокет хоста намеренно НЕ монтируется** |

Про сокет отдельно: смонтировать `/var/run/docker.sock` было бы быстрее (нет вложенного
docker, переиспользуется кеш слоёв хоста), но тогда сборка управляет демоном хоста, и
случайная команда вида `docker rm -f $(docker ps -aq)` в скрипте убивает прод-контейнеры
на этом же сервере. С dind у сборки свой демон, и случайное разрушение локализовано.
Намеренный побег из privileged-контейнера всё равно возможен — это принятый компромисс
за то, что раннер живёт на прод-хосте.

**Что осталось по CI:**

1. `.gitlab-ci.yml` до сих пор в «Emergency low-minutes mode» (август 2026): `workflow`
   пропускает только `$CI_PIPELINE_SOURCE == "web"`, пуши пайплайнов не создают. Ради
   этого раннер и заводился — ограничение можно снимать.
2. **`DEPLOY_SSH_HOST` и `DEPLOY_SSH_KNOWN_HOSTS` в переменных GitLab всё ещё указывают
   на старый сервер**, где приложения больше нет. Обновить до `201.24.55.130` и
   перевыпустить ключ хоста: `ssh-keyscan -p 22 201.24.55.130`.
