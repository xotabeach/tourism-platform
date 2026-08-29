# Backend handoff for Cursor — 2026-08-29

Этот файл — короткая operational handoff-точка для продолжения backend-работы
по [implementation-plan.md](implementation-plan.md) и
[2GIS/personalization/offline plan](2gis-personalization-offline-plan-2026-08-28.md).

## Граница текущей работы

Основной фокус текущего инкремента перенесён на mobile. Mobile Active Route v0
уже реализован в `tourism-mobile` (`630efad`): start/resume, completion
остановок, complete/cancel и обработка конфликта активного прохождения. Cursor
может продолжать backend-очередь ниже, не переделывая этот срез и не меняя
production без отдельного операционного решения. История, L2 offline outbox,
реальная карта/2ГИС SDK и Apple surfaces пока не считаются завершёнными.

## Последнее подтверждённое состояние

- Backend `main`: `e5471eb` (`2GIS Places` safe dry-run + test fixture fix).
- Production image: `e5471eb9bc2e971e45786442c0c3fa212411f086`, direct SSH deploy
  завершён, container healthy, migrations `0039`–`0041` применены.
- `ROUTING_PROVIDER` в production не переключён и остаётся `stub`.
- Server-side 2GIS key в deploy environment на момент проверки отсутствовал;
  значение ключа не читать, не печатать и не коммитить.
- Последний backend gate: 471 passed, 1 skipped, coverage 75.66%; Ruff,
  MyPy и pip-audit зелёные.
- Вызовы 2ГИС после локального smoke не выполнялись. Demo quota ограничена.

## Что уже сделано

1. `TwoGisRoutingProvider`, normalized geometry/altitude, typed errors и
   provider/stop/OSM/road-event quality gate v2.
2. Immutable route-routing snapshots, DB mutation trigger и bounded retention
   cleanup.
3. Sanitized local walking/driving smoke и Places catalog dry-run на 20 точках:
   1 matched, 4 ambiguous, 15 not_found; `--apply` не запускался.
4. Для retention переданы в `/opt/crimeatrip-test` обновлённые Compose и
   `run-route-snapshot-retention.sh`, с backup старого Compose.
   Cron-запись на сервере **не установлена**.

## Следующая backend-очередь

1. При отдельном операционном окне установить cron wrapper и проверить сначала
   dry-run, затем apply. Это не вызывает 2ГИС.
2. После добавления server secret `TWO_GIS_HTTP_API_KEY` выполнить один
   `--configured-only` и один sanitized walking/driving smoke. Только при
   успехе рассматривать `ROUTING_PROVIDER=2gis`; не повторять пробу без
   изменения конфигурации.
3. Закрыть segment-level terrain/access gate: coastline/SRTM, тропы,
   переправы и актуальность дорог; OSM stop tags не являются полным доказательством
   безопасности всего пути.
4. Реализовать recommendations v1: feedback/deck tables, bounded scoring,
   cooldown, diversity/exploration, lazy generation и host cron.
5. Сделать GIS-07 scheduled catalog refresh только после ручного review
   dry-run и quota budget.

## Ограничения для Cursor

- Не вызывать 2ГИС в unit/integration CI и не запускать массовый enrichment.
- Не использовать vendor key в mobile bundle, логах, отчётах или чатах.
- Не применять catalog matches автоматически к названию, координатам,
  расписанию или `publication_status`; ambiguous всегда оставлять на review.
- Любые production-изменения выполнять только после локального `validate.sh`,
  immutable image deploy и health/feature smoke.
