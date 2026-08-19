# Gemma 4 26B в LM Studio на Windows — home lab КрымТрип

Инструкция для выделенного домашнего AI-ПК:

- Windows 11 x64;
- NVIDIA RTX 5070, 12 GB VRAM;
- AMD Ryzen 5 7500F;
- 32 GB DDR5 RAM;
- LM Studio;
- Gemma 4 26B A4B как reasoning/chat-модель.

Мобильное приложение не обращается к этому ПК напрямую. Gemma не получает
пароль от PostgreSQL. LM Studio вызывает только backend КрымТрип: именно
backend выполняет разрешённые запросы к PostGIS и передаёт модели ограниченный
контекст.

## 1. Подготовка Windows

1. Обновить NVIDIA Driver до актуального стабильного Game Ready или Studio
   Driver с официального сайта NVIDIA.
2. Установить LM Studio: <https://lmstudio.ai/download>.
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

1. Открыть `Developer`.
2. Загрузить Unsloth Gemma 4 26B A4B it UD-IQ4_XS.
3. Открыть Local Server settings.
4. Оставить порт `1234`.
5. Сначала слушать только `localhost`.
6. Включить API authentication и создать отдельный backend token.
7. Нажать `Start Server`.

Документация:

- <https://lmstudio.ai/docs/developer/core/server>;
- <https://lmstudio.ai/docs/developer/core/authentication>;
- <https://lmstudio.ai/docs/developer/openai-compat>.

Токен не отправлять в чат и не коммитить.

### Проверка `/v1/models`

```powershell
$LmToken = "ВСТАВИТЬ_ЛОКАЛЬНЫЙ_ТОКЕН"
$Headers = @{ Authorization = "Bearer $LmToken" }

Invoke-RestMethod `
  -Uri "http://127.0.0.1:1234/v1/models" `
  -Headers $Headers
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

## 6. Приватное подключение backend

Порт `1234` нельзя пробрасывать на роутере или публиковать в интернете. Для
удалённого backend используем Tailscale или WireGuard.

1. Установить Tailscale на Windows AI-ПК.
2. Подключить backend-host к той же tailnet.
3. Только после создания API token включить в LM Studio
   `Serve on Local Network`.
4. В Windows Firewall разрешить TCP 1234 только для приватного интерфейса и
   адреса backend-host.
5. Проверить с backend:
   `http://<TAILSCALE_IP_WINDOWS>:1234/v1/models`.
6. Postgres для Windows не открывать: к БД обращается backend, а не Gemma.

Сетевой режим LM Studio:
<https://lmstudio.ai/docs/developer/core/server/serve-on-network>.

Backend-конфигурация, без реального секрета в Git:

```env
AI_PLANNING_ENABLED=false
AI_PROVIDER=lmstudio
LM_STUDIO_BASE_URL=http://<TAILSCALE_IP_WINDOWS>:1234/v1
LM_STUDIO_MODEL=<ТОЧНЫЙ_ID_ИЗ_V1_MODELS>
LM_STUDIO_API_KEY=<SECRET>
AI_REQUEST_TIMEOUT_SECONDS=60
AI_MAX_REPAIR_ATTEMPTS=1
RAG_ENABLED=false
```

Settings и OpenAI-compatible connectivity probe реализованы в backend
`0aee04c`; пользовательские planning endpoints пока не включены. Флаги по
умолчанию выключены.

Проверка с машины, которая должна обращаться к LM Studio:

```bash
cd tourism-backend
LM_STUDIO_BASE_URL=http://<TAILSCALE_IP_WINDOWS>:1234/v1 \
LM_STUDIO_MODEL='<ТОЧНЫЙ_ID_ИЗ_V1_MODELS>' \
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
- [ ] LM Studio установлен.
- [ ] Загружена Unsloth Gemma 4 26B A4B it UD-IQ4_XS GGUF.
- [ ] Context 8192 стабилен.
- [ ] Записаны tok/s, VRAM и RAM.
- [ ] `/v1/models` отвечает на localhost.
- [ ] `/v1/chat/completions` отвечает с API token.
- [ ] Порт 1234 не открыт в WAN.
- [ ] Tailscale/WireGuard настроен до LAN serve.
- [ ] Backend-host видит API по приватному адресу.
- [ ] Секрет не хранится в Git.

Следующий этап — retrieval опубликованных places, JSON-schema validator и
deterministic fallback. RAG включается после стабильного каталога PostGIS.
