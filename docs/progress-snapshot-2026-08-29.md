# Промежуточный срез реализации — 2026-08-29

Этот документ фиксирует состояние проекта на 29 августа 2026 года после
последнего мобильного инкремента. Он нужен как точка передачи работы между
агентами и как короткая сверка с [планом реализации](implementation-plan.md),
[executable blueprint](implementation-blueprint-2026-08.md) и расширенным
[планом 2ГИС, персонализации и offline](2gis-personalization-offline-plan-2026-08-28.md).

## Как читать статус

**Сделано** означает, что функциональность находится в `main` соответствующего
репозитория. **В работе** означает незакоммиченные изменения в рабочем дереве;
они принадлежат текущей работе Cursor и в этот срез не включены. **Не сделано**
означает отсутствие готового пользовательского контура, даже если есть
частичные заготовки или документация.

Подтверждённые ветки на момент среза:

| Репозиторий | `main` | Рабочее дерево |
| --- | --- | --- |
| Backend | `d616726` — recommendations v1 | AI candidate DTOs — в работе, не закоммичены |
| Mobile | `a37cf24` — secure offline route-execution outbox | alias `APP_ENV=prod` и security-тест — в работе, не закоммичены |
| Platform | `bbc9aba` — recommendations/deploy documentation | несколько документов Cursor изменены, не закоммичены |

## Backend

| Область плана | Состояние | Что реально доступно |
| --- | --- | --- |
| Foundation, auth и базовая безопасность (Phase 0–2, review phases 0–6) | **Сделано** | Versioned API, health/readiness, OTP/JWT, refresh/quota locks, publication/authZ-фильтры, security tests и базовые quality gates. |
| Places и editorial routes (Phase 3–4) | **Сделано, данные требуют развития** | Каталог, карточки, избранное, отзывы, публикация и route builder API. Узкое место — полнота и редакционная проверка каталога. |
| Route execution backend v0 | **Сделано** | Start/resume/list/get-active, ownership/BOLA, state machine остановок, complete/cancel, conflict активного маршрута. Миграции `0039`–`0041` добавляют immutable routing snapshot, quality facts и bounded retention. |
| 2ГИС HTTP routing и quality gate v2 | **Сделано локально** | Server-side `TwoGisRoutingProvider`, walking/driving geometry, typed errors, высоты, время и provenance; фильтры закрытых дорог/переправ и provider/OSM/road-event проверки. По умолчанию production остаётся на `stub`. |
| Production 2ГИС | **Не сделано** | Нужны подтверждение server secret по наличию, один `configured-only` smoke и один санитизированный walking/driving smoke. Не повторять запросы без изменения конфигурации: demo-квота ограничена. |
| GIS-06 catalog enrichment | **Сделано как dry-run** | На bounded batch 20 точек: 1 matched, 4 ambiguous, 15 not_found; `--apply` не запускался. Автопубликации и автоматической записи названий/координат/часов нет. |
| GIS-07 scheduled refresh | **Не сделано** | Нужны ручной review dry-run, quota budget, allowlist полей, журнал изменений и rollback. |
| Route quality: terrain/coastline/SRTM | **Частично** | Есть gate на provider geometry, legs, уклон, pace/gain/dirt/ferry и OSM stop-data. Нет полноценной segment-level проверки всего пути: береговой линии, высотного профиля SRTM, троп, бродов и актуальных road events. |
| Recommendations R1 v1 | **Сделано** | `GET /routes/recommendations/today`, idempotent `skip` feedback, migration `0042`, daily Moscow-time deck, explicit preferences, popularity/freshness, cooldown, diversity/exploration и explanation code. Host generator работает dry-run; серверный cron колоды не установлен. |
| AI-01 approved candidate DTOs | **В работе** | В рабочем дереве Cursor есть изменения для allowlist published/quality-approved мест, freshness/data-quality и hard gates. До отдельного review/test/commit считать незавершённым. |
| Production release | **Сделано для текущего backend main** | Образ `d6167268581933cabb7b4ee93578f7cf70389318` развёрнут direct deploy, миграции `0039`–`0042` применены, readiness был зелёным, unauthenticated recommendations API возвращал `401`. 2ГИС provider в production не переключён. |

Последний зафиксированный backend gate после R1: **484 passed, 1 skipped,
coverage 75.57%; Ruff, MyPy и pip-audit зелёные**. 2ГИС-вызовы в CI и массовый
enrichment запрещены.

## Mobile

| Область плана | Состояние | Что реально доступно |
| --- | --- | --- |
| Shell, навигация, тема, API/mock foundation (Phase 5–5.5) | **Сделано** | Stateful shell, Riverpod, typed config, secure storage, API/mock separation, responsive screens и базовые goldens. |
| Auth/profile/preferences | **Сделано** | Вход/сессия, профиль, персональные предпочтения, лёгкий quiz, prompt для незаполненных предпочтений, reset и logout. Logout очищает локальные route snapshots и execution state. |
| Places/routes/favorites/reviews | **Сделано** | Каталог и детали мест/маршрутов, избранное, отзывы, фильтры и quality/freshness presentation там, где API это отдаёт. |
| L1 offline routes | **Сделано** | Versioned snapshots: сохранить, открыть при сетевой ошибке, список скачанных маршрутов, удалить один или очистить всё. |
| Active Route v0 | **Сделано** | Start/resume, прогресс остановок, complete/cancel, conflict активного маршрута, quality warnings, история через backend `GET /route-executions`. |
| L2 offline execution | **Сделано частично** | Secure Keychain/Keystore snapshot + outbox с idempotent replay, optimistic local completion, Retry и replay при открытии Active Route. Нет фонового connectivity worker/background sync и отдельного device-smoke. |
| Recommendations R2 mobile deck | **Частично** | API-модели/repository/providers и explanation badge на карточке есть. Полный экран/слайдер на daily deck, skip analytics и UX-поведение нового API ещё не доведены до acceptance criteria. |
| Карта в приложении и native 2ГИС SDK | **Не сделано** | Нет production map bridge, attribution/error states, iOS/Android SDK integration и проверки SDK-ключа. HTTP demo key backend не заменяет Mobile SDK subscription/licence. |
| Навигация | **Не сделано** | Есть route execution и подготовленный hand-off, но нет turn-by-turn GPS, голосовых подсказок, background location, deep-link policy и полноценного офлайн-навигационного пакета. Переход во внешнее приложение 2ГИС — отдельный fallback, не готовый основной flow. |
| Offline login/shell | **Частично** | Данные маршрута уже доступны офлайн после сохранения; полноценная офлайн-сессия с безопасным refresh/expiry и понятным re-auth UX ещё не закрыта. |
| Apple WidgetKit / Dynamic Island | **Не сделано** | Нет native targets, live activity contract и privacy/permission QA. |
| Travel+, audio guide и другие monetization surfaces | **Проверить отдельно** | В текущем срезе не считаем функциональными без end-to-end backend contract и acceptance test; UI-заготовки не являются готовой оплатой/контентом. |

После `a37cf24` мобильный gate подтверждён: **286 функциональных тестов и 25
golden-тестов прошли**, format/analyze зелёные (оставшееся предупреждение tap
offscreen в `places_filters_test.dart` не блокирует gate). Незакоммиченные
изменения Cursor в `app_config.dart` и `config_security_test.dart` намеренно
не включены.

## Что закрыто по пользовательским сценариям

1. Пользователь может войти, заполнить предпочтения, просматривать места и
   маршруты, открыть сохранённый маршрут без сети и выйти с очисткой локальных
   данных.
2. Пользователь может начать маршрут, продолжить его, отмечать остановки,
   завершить или отменить прохождение; состояние синхронизируется с backend.
3. Backend может сформировать ограниченную персональную daily-колоду и принять
   идемпотентный `skip`.

Главный незакрытый сценарий — «выбрать безопасный реальный маршрут на карте,
построить его по дорогам/тропам, пройти с GPS и продолжить без сети».

## Рекомендуемый следующий порядок

### Backend-first

1. Завершить AI-01 рабочие изменения Cursor: tests, security review, commit и
   deploy только после зелёного backend gate.
2. В операционное окно подтвердить наличие `TWO_GIS_HTTP_API_KEY` на production
   без вывода значения; выполнить ровно один санитизированный smoke. Переключать
   `ROUTING_PROVIDER=2gis` только после acceptance и rollback-плана.
3. Реализовать segment-level route quality: coastline/SRTM, профиль высот,
   тропы/броды, surface/sac_scale, сезонные и дорожные события. До этого не
   обещать пользователю безопасную навигацию по сложному рельефу.
4. Подготовить GIS-07 refresh: dry-run → editorial review → allowlisted apply →
   audit/rollback; затем установить отдельный cron daily recommendations с
   quota budget и алертами.

### Mobile-next

1. Довести R2 daily recommendation deck до полного контракта: загрузка,
   pagination/refresh, skip feedback, empty/error/loading/offline states,
   telemetry без персональных данных и diversity UX.
2. Добавить background/foreground outbox replay, connectivity transitions,
   duplicate/conflict recovery и device tests для iOS/Android.
3. После получения Mobile SDK key/licence сделать M1 map abstraction и M2
   2ГИС bridge: attribution, markers, route geometry, error/fallback states,
   external 2ГИС hand-off. Не встраивать HTTP key в приложение.
4. После стабильного execution/map flow — GPS/turn-by-turn, voice, background
   location, offline map package и только потом WidgetKit/Dynamic Island.
5. Закрыть UX-долги: dead `/search`, back navigation auth screens, a11y icon
   contract, design tokens и оставшийся performance review.

## Gates и ограничения

- Ни один CI job не должен вызывать 2ГИС и расходовать demo quota.
- Ключи 2ГИС не коммитятся, не попадают в mobile bundle, логи, отчёты или
  prompt/model context.
- `ambiguous` catalog matches никогда не публикуются автоматически.
- До segment-level quality gate не показывать маршрут как гарантированно
  безопасный для автомобиля/пешехода.
- Любой production change: local validate → immutable image → migration/API
  smoke → readiness → rollback check. Пуши выполняются с `[ci skip]`.

## Точка передачи

Operational handoff для продолжения backend: [cursor-backend-handoff-2026-08-29.md](cursor-backend-handoff-2026-08-29.md).
Полный живой статус: [progress.md](progress.md). Этот snapshot можно обновлять
новым датированным файлом после следующего принятого инкремента, не переписывая
историю и не выдавая незакоммиченные изменения за релиз.
