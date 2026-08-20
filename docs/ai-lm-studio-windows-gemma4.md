# Gemma 4 26B в LM Studio на Windows — home lab КрымТрип

Инструкция для выделенного домашнего AI-ПК:

- Windows 11 x64;
- NVIDIA RTX 5070, 12 GB VRAM;
- AMD Ryzen 5 7500F;
- 32 GB DDR5 RAM;
- LM Studio Bionic и обычный LM Studio Desktop;
- Gemma 4 26B A4B как reasoning/chat-модель.

Мобильное приложение не обращается к этому ПК напрямую. Gemma не получает
пароль от PostgreSQL. LM Studio вызывает только backend КрымТрип: именно
backend выполняет разрешённые запросы к PostGIS и передаёт модели ограниченный
контекст.

## 0. Важно: Bionic — отдельное приложение

LM Studio Bionic — не новая тема и не очередная версия интерфейса обычного
LM Studio, а отдельное приложение. Оно рассчитано прежде всего на работу с
локальными coding-агентами. Раздел Bionic
`Settings → Local Models → Local Model API` не заменяет описанный ниже экран
управления OpenAI-compatible сервером.

Для КрымТрип используем оба приложения:

- **Bionic** можно оставить для чатов, агентов и уже загруженной модели;
- **обычный LM Studio Desktop** нужен для управляемого API: `Developer`,
  `Start Server`, токены, порт и сетевые ограничения;
- удалять Bionic и заново скачивать модель заранее не нужно.

WireGuard не заменяет LM Studio Desktop: VPN создаёт только защищённый путь
`backend → Windows`, а HTTP API модели всё равно должен быть запущен на
Windows. От Desktop можно будет отказаться лишь тогда, когда Bionic или
отдельный `llmster` предоставит и мы проверим тот же authenticated API,
network bind, `/v1/models` и `/v1/chat/completions`.

Сначала открыть PowerShell и проверить, доступна ли модель общему runtime:

```powershell
lms --version
lms ls
```

Если в выводе есть
`unsloth/gemma-4-26b-a4b-it-ud-iq4-xs`, повторная загрузка не требуется. Если
модели нет, не удалять и не переносить GGUF: найти путь к файлу модели в
Bionic и добавить этот файл в библиотеку обычного LM Studio. В спорном случае
сначала сохранить путь и скриншот экрана модели — это безопаснее повторной
загрузки 13+ GB или ручного перемещения файла.

Официальное описание различий:

- <https://lmstudio.ai/blog/introducing-lm-studio-bionic>;
- <https://lmstudio.ai/docs/bionic>;
- <https://lmstudio.ai/docs/app/basics/lmstudio-vs-llmster-vs-lms>.

## 1. Подготовка Windows

1. Обновить NVIDIA Driver до актуального стабильного Game Ready или Studio
   Driver с официального сайта NVIDIA.
2. Не удаляя Bionic, установить обычный **LM Studio Desktop**:
   <https://lmstudio.ai/download>.
3. Перезагрузить ПК после обновления драйвера.
4. Выбрать для LM Studio высокопроизводительный GPU:
   `Параметры → Система → Дисплей → Графика → LM Studio → Высокая
   производительность`.
5. Отключить автоматический сон ПК на время серверной работы. Выключение экрана
   допустимо.

Требования LM Studio: <https://lmstudio.ai/docs/app/system-requirements>.

## 2. Модель

Фактически установленная модель:

```text
unsloth/gemma-4-26b-a4b-it-ud-iq4-xs
```

Репозиторий/файл:

```text
unsloth/gemma-4-26B-A4B-it-GGUF
gemma-4-26B-A4B-it-UD-IQ4_XS.gguf
```

Важно:

- нужен **GGUF**, не MLX;
- `it` — instruction-tuned вариант;
- Unsloth Dynamic `UD-IQ4_XS` GGUF занимает около 13.4 GB;
- модель целиком не помещается в 12 GB VRAM, поэтому часть весов будет в
  32 GB системной RAM;
- 26B A4B — MoE: всего около 25.2B параметров, активно около 3.8B на токен.

Карточки модели:

- <https://lmstudio.ai/models/google/gemma-4-26b-a4b>
- <https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF>

## 3. Первая загрузка

| Параметр | Начальное значение |
| --- | --- |
| GPU Offload | `Auto` |
| Context Length | `8192` |
| Flash Attention | включить, если доступно |
| Enable Thinking | включить |
| Temperature | model default для smoke-теста |

Не ставить сразу 128K/256K: большой KV-cache требует дополнительной памяти.
Для первого RAG достаточно 8K; после замеров проверим 16K.

Контроль во время запуска:

- VRAM не должна уходить в OOM;
- общая RAM не должна постоянно приближаться к 32 GB;
- при нехватке памяти сначала уменьшить context, затем GPU offload;
- не запускать одновременно игры или вторую крупную модель.

## 4. Smoke-тест модели

Во встроенном чате:

```text
Ты помощник туристического приложения. Ответь по-русски двумя предложениями:
почему часы работы и закрытие маршрута нельзя угадывать по памяти модели?
```

Затем structured-output smoke:

```text
Верни только JSON без markdown:
{"status":"ok","language":"ru","warnings":[]}
```

Записать результат:

| Дата | LM Studio | Model revision | Context | GPU offload | tok/s | VRAM | RAM |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| | | | 8192 | Auto | | | |

## 5. Локальный API

Следующие пункты выполняются в обычном LM Studio Desktop, не в настройке
`Local Model API` приложения Bionic.

1. Открыть вкладку `Developer` (`</>`).
2. Загрузить Unsloth Gemma 4 26B A4B it UD-IQ4_XS.
3. При загрузке задать Context Length `8192`, GPU Offload `Auto` и включить
   Flash Attention, если настройка доступна.
4. Открыть `Server Settings` и оставить порт `1234`.
5. Включить `Require Authentication`.
6. Открыть `Manage Tokens`, создать токен с названием
   `crimeatrip-backend` и сразу скопировать его: повторно значение не
   показывается.
7. Для первого теста оставить выключенными:
   `Serve on Local Network`, CORS, оба переключателя MCP, JIT loading и
   auto-unload.
8. Нажать `Start Server`.

Токен хранится только как секрет backend с именем `LM_STUDIO_API_KEY`. Его
нельзя отправлять в чат, встраивать в Flutter, сохранять в БД или коммитить.

Документация:

- <https://lmstudio.ai/docs/developer/core/server>;
- <https://lmstudio.ai/docs/developer/core/authentication>;
- <https://lmstudio.ai/docs/developer/openai-compat>.

### Проверка `/v1/models`

```powershell
$LmToken = "ВСТАВИТЬ_ЛОКАЛЬНЫЙ_ТОКЕН"
$Headers = @{ Authorization = "Bearer $LmToken" }

$Models = Invoke-RestMethod `
  -Uri "http://127.0.0.1:1234/v1/models" `
  -Headers $Headers

$Models.data | Select-Object id
```

Скопировать точный `id` модели из ответа.

### Проверка `/v1/chat/completions`

```powershell
$ModelId = "ТОЧНЫЙ_ID_ИЗ_V1_MODELS"
$Body = @{
  model = $ModelId
  messages = @(
    @{ role = "user"; content = "Ответь одним словом: сервер работает?" }
  )
  temperature = 0.2
  max_tokens = 100
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:1234/v1/chat/completions" `
  -Headers $Headers `
  -ContentType "application/json" `
  -Body $Body
```

Если интерфейс сервера уже был настроен, его можно запускать из PowerShell:

```powershell
lms server start --port 1234
```

Создание токена и проверку сетевых переключателей всё равно выполнить в
`Developer → Server Settings` обычного LM Studio Desktop.

## 6. Приватное подключение backend

Порт `1234` нельзя пробрасывать на роутере или публиковать в интернете. Для
удалённого backend используем WireGuard. Backend уже находится на VPN-сервере,
поэтому маршрутизация чужого трафика и доступ Windows к подсети Docker не
нужны: создаётся только узкий tunnel `server ↔ AI-PC`.

План адресов:

| Узел | WireGuard IP | Что слушает |
| --- | --- | --- |
| backend-сервер | `10.77.0.1/24` | WireGuard UDP `51820` |
| Windows AI-ПК | `10.77.0.2/32` | LM Studio TCP `1234` |

### 6.1. Windows: импортировать tunnel

1. Установить официальный WireGuard for Windows.
2. Выбрать `Add Tunnel → Import tunnel(s) from file`.
3. Импортировать полученный файл `crimeatrip-ai-windows.conf` и включить
   tunnel.
4. Не открывать и не отправлять содержимое файла: внутри находится приватный
   ключ Windows peer.

Фактически подготовленный клиентский tunnel имеет вид:

```ini
[Interface]
PrivateKey = <GENERATED_WINDOWS_PRIVATE_KEY>
Address = 10.77.0.2/32

[Peer]
PublicKey = <GENERATED_SERVER_PUBLIC_KEY>
Endpoint = 86.106.20.132:51820
AllowedIPs = 10.77.0.1/32
PersistentKeepalive = 25
```

`AllowedIPs = 10.77.0.1/32` делает tunnel split-tunnel: обычный интернет
Windows через сервер не идёт.

### 6.2. Серверный peer

Ключи сгенерированы **на сервере** и не попадают в Git. Конфигурация
`/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 10.77.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
PublicKey = <WINDOWS_PUBLIC_KEY>
AllowedIPs = 10.77.0.2/32
PersistentKeepalive = 25
```

Keepalive нужен **на обеих сторонах** (Windows client и server peer): иначе после
NAT timeout latest handshake устаревает, и TCP к LM Studio (`10.77.0.2:1234`)
начинает таймаутиться. На сервере с 2026-08-20 выставлено
`PersistentKeepalive = 25` live + в `/etc/wireguard/wg0.conf`.

Целевое состояние host firewall — открыть для WireGuard только `51820/udp`.
Порт `1234/tcp` на публичном сервере открывать не нужно. На текущем
Ubuntu-хосте `ufw` пока не активирован, а INPUT policy — ACCEPT; включать UFW
без отдельного аудита SSH `6579`, Caddy и Docker chains нельзя, чтобы не
оборвать deploy и публичный API. После запуска `wg0` проверить на сервере
`wg show` и доступность `10.77.0.2`.

### 6.3. Ограничить LM Studio

1. Сначала создать API token, затем включить в LM Studio
   `Serve on Local Network`.
2. В Windows Firewall разрешить входящий TCP `1234` только от
   `10.77.0.1`. Не принимать стандартное широкое правило для Public network.
3. На backend использовать
   `http://10.77.0.2:1234/v1` и созданный API token.
4. Проверить `/v1/models`, затем `scripts/check_lm_studio.py`.
5. Postgres для Windows не открывать: к БД обращается backend, а не Gemma.

По состоянию на 2026-08-19 `wg0` установлен, включён в автозапуск и слушает
`10.77.0.1:51820/udp`; peer `10.77.0.2/32` добавлен. Клиентский конфиг передан
отдельным локальным файлом, после чего его приватный ключ и копия конфига
удалены с сервера. Приватные ключи и LM Studio token в переписку и Git не
отправляются.

### 6.4. Checkpoint 2026-08-20 (обновлено)

Подтверждено:

- WireGuard tunnel + `PersistentKeepalive = 25` настроены; handshake проходит.
- LM Studio Desktop слушает локально; model id `gemma-4-26b-it`.
- API token в `/opt/crimeatrip-test/.env` (mode `600`); в Git не попадает.
- Стабильный путь API: Windows-initiated SSH reverse на loopback VPS +
  forward на docker bridge (детали старта — только на сервере
  `/opt/crimeatrip-test/HOME_LAB_START.md`, не в этом публичном doc).
- Backend: `AI_PROVIDER=lmstudio`, `check_lm_studio.py` OK;
  `reasoning_effort=none` для Gemma 4. Planning/RAG **выключены**.

Не завершено (Phase 8B):

- пользовательский AI-chat session API в мобильном «Подборе»;
- включение `AI_PLANNING_ENABLED` после session/quota/BOLA;
- устойчивый WireGuard server→Windows TCP (опционально вместо reverse SSH).

Backend-конфигурация (без секретов; URL — docker-bridge forward на VPS):

```env
AI_PLANNING_ENABLED=false
AI_PROVIDER=lmstudio
LM_STUDIO_BASE_URL=http://172.19.0.1:1234/v1
LM_STUDIO_MODEL=gemma-4-26b-it
LM_STUDIO_API_KEY=<SECRET>
AI_REQUEST_TIMEOUT_SECONDS=60
AI_MAX_REPAIR_ATTEMPTS=1
RAG_ENABLED=false
```

Сетевой режим LM Studio:
<https://lmstudio.ai/docs/developer/core/server/serve-on-network>.

Settings и OpenAI-compatible connectivity probe реализованы в backend;
пользовательские planning endpoints пока не включены. Флаги по умолчанию
выключены.

Проверка с хоста/контейнера, у которого есть путь к LM Studio:

```bash
cd tourism-backend
LM_STUDIO_BASE_URL=http://172.19.0.1:1234/v1 \
LM_STUDIO_MODEL='gemma-4-26b-it' \
LM_STUDIO_API_KEY='<SECRET>' \
uv run python scripts/check_lm_studio.py
```

Команда сначала сверяет model ID через `/v1/models`, затем выполняет один
ограниченный нестриминговый structured chat request. Секрет в вывод не
попадает.

## 7. Поток данных

```text
Flutter -> HTTPS FastAPI backend
                    |-> PostGIS: координаты, фильтры, цены, закрытия, входы
                    |-> Qdrant: история, описания, советы, semantic search
                    `-> LM Studio: reasoning и структурированный ответ
```

Backend валидирует запрос, получает кандидатов PostGIS и RAG-фрагменты,
передаёт Gemma только разрешённые `place_id`, затем проверяет JSON, ограничения
времени/расстояния и при ошибке использует bounded repair или deterministic
fallback.

## 8. RAG и обучение

Сейчас модель **не обучаем**:

- строки PostGIS не являются датасетом fine-tuning;
- embedding + Qdrant не меняют веса Gemma;
- актуальные факты остаются в PostGIS;
- LM Studio используется для inference/API, не как trainer.

LoRA рассматриваем после gold-set тестов. Датасет LoRA — пары «запрос +
кандидаты → эталонный JSON», а не dump таблицы `places`.

## 9. Переход с 8K на 16K

Увеличить Context Length до `16384`, только если:

- пять последовательных запросов прошли без OOM;
- RAM/VRAM имеют стабильный запас;
- скорость подходит для API;
- JSON не обрывается;
- Windows не использует pagefile непрерывно под нагрузкой.

## 10. Чеклист готовности

- [ ] NVIDIA driver обновлён.
- [ ] Bionic оставлен для агентов, обычный LM Studio Desktop установлен для API.
- [ ] Загружена Unsloth Gemma 4 26B A4B it UD-IQ4_XS GGUF.
- [ ] Context 8192 стабилен.
- [ ] Записаны tok/s, VRAM и RAM.
- [ ] `/v1/models` отвечает на localhost.
- [ ] `/v1/chat/completions` отвечает с API token.
- [x] Порт LM Studio 1234 не публиковался в WAN.
- [x] WireGuard `10.77.0.1 ↔ 10.77.0.2` настроен до LAN serve.
- [ ] Backend-host видит API по приватному адресу.
- [x] Секрет не хранится в Git.

Следующий этап — retrieval опубликованных places, JSON-schema validator и
deterministic fallback. RAG включается после стабильного каталога PostGIS.
