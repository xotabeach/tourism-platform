# Backend handoff for Cursor — 2026-08-29

Этот файл — короткая operational handoff-точка для продолжения backend-работы
по [implementation-plan.md](implementation-plan.md) и
[2GIS/personalization/offline plan](2gis-personalization-offline-plan-2026-08-28.md).

## Граница текущей работы

Mobile Active Route v0 реализован в `tourism-mobile` (`b970333`): start/resume,
completion остановок, complete/cancel, история через `GET /route-executions` и
обработка конфликта активного прохождения. Дальше Codex подключил
персонализированную колоду (`4fddf6d`/`cc5a6e2`) и клиентскую часть L2
execution outbox (`a37cf24`). Backend-часть L2 (idempotent sync, миграция
`0043`) сделана в текущем срезе, но ещё **не задеплоена**. Реальная
карта/2ГИС SDK, L0 offline session и Apple surfaces не считаются
завершёнными; отдельная аналитика и глубокая history pagination остаются вне
текущего среза.

## Последнее подтверждённое состояние

- Backend `main`: `d616726` (recommendations v1: миграция `0042`, ranker,
  `GET /routes/recommendations/today`, skip feedback).
- Production image: `d6167268581933cabb7b4ee93578f7cf70389318`, direct SSH deploy
  2026-08-29, container healthy, migrations `0039`–`0042` применены.
  Unauthenticated today/skip API возвращает `401`, не `404`.
- Незадеплоено: AI-01 и OFF-02 (`0043_route_execution_events`) существуют
  только локально. Production при следующем deploy должен получить `0043`.
- `ROUTING_PROVIDER` в production не переключён и остаётся `stub`.
- Server-side 2GIS key в deploy environment на момент проверки отсутствовал;
  значение ключа не читать, не печатать и не коммитить.
- Последний backend gate (после R1): 484 passed, 1 skipped, coverage 75.57%;
  Ruff, MyPy и pip-audit зелёные.
- Вызовы 2ГИС после локального smoke не выполнялись. Demo quota ограничена.

## Что уже сделано

1. `TwoGisRoutingProvider`, normalized geometry/altitude, typed errors и
   provider/stop/OSM/road-event quality gate v2.
2. Immutable route-routing snapshots, DB mutation trigger и bounded retention
   cleanup.
3. Sanitized local walking/driving smoke и Places catalog dry-run на 20 точках:
   1 matched, 4 ambiguous, 15 not_found; `--apply` не запускался.
4. Retention wrapper на хосте; cron установлен 2026-08-29
   (`20 0 * * *` UTC). Dry-run перед установкой: scanned=0 / deleted=0.
   Лог: `/var/log/crimeatrip-retention.log`. Dashboard-алерты отдельно.
5. Recommendations v1 (`d616726`) задеплоен: `0042`, lazy deck, skip
   feedback, host-скрипт dry-run. Cron колоды на сервере не ставили;
   mobile R2 не подключён.
6. AI-01: planning tools (`search_places` / `get_place_details` /
   `find_places_near_point`) отдают только published, не закрытые,
   не `rejected`/`merged` и не OSM-forbidden кандидаты; DTO с
   `freshness_status` / `data_quality_status`, без payload/координат/часов.
7. OFF-02 (L2) backend: миграция `0043_route_execution_events` и idempotent
   execution sync. Мутации принимают необязательный
   `{client_event_id, occurred_at}`; повтор возвращает состояние и
   `sync.replayed=true`. Клиентское время bounded (future > 5 мин skew и
   старше 30 дней → `422`; раньше `started_at` → зажимается). Терминальные
   конфликты помечены `details.retryable=false`. Локальный gate: 505 passed,
   1 skipped, coverage 75.69%. Deploy не выполнялся.

## Следующая backend-очередь

1. ~~При отдельном операционном окне установить cron wrapper и проверить сначала
   dry-run, затем apply.~~ Сделано 2026-08-29. Следующий ночной прогон —
   00:20 UTC; смотреть `/var/log/crimeatrip-retention.log`.
2. После добавления server secret `TWO_GIS_HTTP_API_KEY` выполнить один
   `--configured-only` и один sanitized walking/driving smoke. Только при
   успехе рассматривать `ROUTING_PROVIDER=2gis`; не повторять пробу без
   изменения конфигурации.
3. Закрыть segment-level terrain/access gate: coastline/SRTM, тропы,
   переправы и актуальность дорог; OSM stop tags не являются полным доказательством
   безопасности всего пути.
4. ~~Реализовать recommendations v1: feedback/deck tables, bounded scoring,
   cooldown, diversity/exploration, lazy generation и host cron.~~ Сделано
   2026-08-29 (`0042`, API, dry-run script). Cron колоды на сервере не
   ставили; mobile R2 подключён Codex (`4fddf6d`).
5. Сделать GIS-07 scheduled catalog refresh только после ручного review
   dry-run и quota budget.
6. ~~AI intent → approved candidate DTOs.~~ Сделано 2026-08-29.
7. ~~L2 execution outbox backend: idempotent replay, client event ledger и
   bounded offline время.~~ Сделано 2026-08-29 (`0043`). Deploy остаётся.
8. Сделать L0 offline session: bounded grace period и refresh metadata в
   auth-контракте. Старый access token не считается бессрочной авторизацией.

## Ограничения для Cursor

- Не вызывать 2ГИС в unit/integration CI и не запускать массовый enrichment.
- Не использовать vendor key в mobile bundle, логах, отчётах или чатах.
- Не применять catalog matches автоматически к названию, координатам,
  расписанию или `publication_status`; ambiguous всегда оставлять на review.
- Любые production-изменения выполнять только после локального `validate.sh`,
  immutable image deploy и health/feature smoke.
