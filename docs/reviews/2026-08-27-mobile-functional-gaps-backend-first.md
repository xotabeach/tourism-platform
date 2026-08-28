# Инвентаризация mock и нефункциональных элементов mobile/backend

Дата: 2026-08-27  
Статус: backend-first реализация начата; ещё не закрыто mobile consumer  
Приоритет реализации: **backend first**

Проверенные ревизии:

| Репозиторий | `main` |
| --- | --- |
| workspace | `1a5113b00f912df3a2b60f2c4f0cd1db08946613` |
| tourism-mobile | `fdc0837c828e783a940615804454d68dce15ba80` |
| tourism-backend | `16dcea67822bad496392ad0b6c9b6b5aec489a6c` |
| tourism-platform | `0009fd3f33c4d30eda35d6e3b4ab16e4bd2ae1fb` |

Связанные документы:

- [Полное ревью проекта](2026-08-27-full-project-review.md)
- [План исправлений после ревью](2026-08-27-review-remediation-plan.md)
- [As-built спецификация мобильных экранов](../mobile-screens-business-spec.md)

## Цель

Зафиксировать всё, что уже показано пользователю в мобильной вёрстке, но:

- не выполняет полезного действия;
- заканчивается snackbar-сообщением «появится позже»;
- использует hardcoded/mock данные даже при работе с API;
- меняет только локальное состояние, не реализуя заявленный use case;
- не имеет необходимого backend API или инфраструктуры.

Это не общий code review. Архитектурный долг, безопасность и производительность включаются сюда только
тогда, когда они непосредственно объясняют неработающий пользовательский сценарий.

## Правило реализации

1. Сначала реализуются доменная модель, миграции, API, права доступа и тесты backend.
2. Затем mobile подключается к готовому контракту.
3. Если необходимого экрана ещё нет, агент создаёт полноценный рабочий экран в стиле текущего
   приложения: использует существующие design tokens, компоненты, motion и паттерны состояний, но
   может самостоятельно выбрать композицию и визуальные решения.
4. Это не wireframe и не «техническая заглушка»: новый экран должен выглядеть законченным уже в
   первой версии. Дальнейшая полировка возможна после появления отдельного дизайна, но не является
   условием запуска backend-сценария.
5. В production/staging нельзя подменять отсутствующую возможность успешным mock-сценарием.
6. Если функция ещё не готова, UI должен честно показывать её недоступность или не показывать control.

## Обозначения

| Метка | Значение |
| --- | --- |
| `NO-OP` | control виден, но полезного действия нет |
| `MOCK` | действие имитирует результат без реальной интеграции |
| `LOCAL` | данные/состояние существуют только в памяти приложения |
| `BACKEND GAP` | для сценария нет API, хранилища или фонового процесса |
| `PARTIAL` | часть сценария работает, но обещанный результат не достигается |

Приоритеты:

- **P1** — блокирует основной пользовательский цикл, доверие к данным или внешнее тестирование.
- **P2** — заметная пользователю неполнота, не блокирующая основной каталог.
- **P3** — вторичный UX или документационная честность.

## Сводка

| ID | Приоритет | Экран/сценарий | Тип | Кратко |
| --- | --- | --- | --- | --- |
| FNC-01 | P1 | Пройти маршрут | `NO-OP`, `BACKEND GAP` | CTA показывает snackbar; execution API отсутствует |
| FNC-02 | P1 | Ошибка на маршруте | `MOCK`, `PARTIAL` | список маршрутов hardcoded, `route_id` не отправляется |
| FNC-03 | P1 | OTP / смена телефона | `BACKEND GAP` | SMS-провайдер не подключён |
| FNC-04 | P1 | Расчёт маршрута | `MOCK`, `PARTIAL` | расстояние и геометрия синтетические |
| FNC-05 | P1 | Travel+ | `MOCK` | нет store billing, форма карты тестовая |
| FNC-06 | P2 | Карточка маршрута | `NO-OP` | share, offline, menu и audio — snackbar |
| FNC-07 | P2 | Карточка места | `NO-OP` | audio — snackbar; pin на preview ничего не делает |
| FNC-08 | P2 | AI-предложение | `NO-OP` | «Посмотреть карту» — snackbar |
| FNC-09 | P2 | История маршрутов | `MOCK` | показываются первые шесть маршрутов каталога |
| FNC-10 | P2 | Swipe deck | `LOCAL`, `BACKEND GAP` | skip живёт только до пересоздания экрана |
| FNC-11 | P2 | Оффлайн маршруты | `LOCAL`, `BACKEND GAP` | переключатели есть, скачивания нет |
| FNC-12 | P2 | Поддержка / настройки | `NO-OP` | About, Rate, два FAQ-раздела — «позже» |
| FNC-13 | P2 | Профиль | `NO-OP`, `PARTIAL` | refresh чужого профиля пустой; tap достижения — snackbar |
| FNC-14 | P2 | AI-чат | `MOCK` | backend допускает детерминированный mock provider |
| FNC-15 | P3 | Документация backend | stale docs | README неверно называет два живых модуля заглушками |

## Экранный аудит mobile

### Welcome и авторизация

#### FNC-03 — доставка OTP отсутствует

**Что видит пользователь:** экран обещает вход по коду из SMS.  
**Фактически:** backend создаёт OTP challenge, но отправка в SMS gateway оставлена как `TODO`.

Доказательства:

- `tourism-backend/src/tourism_backend/modules/identity/application/service.py:169`
- `tourism-backend/src/tourism_backend/modules/identity/application/service.py:601`

В local mobile использует `MockAuthRepository`, а полный четырёхзначный код принимается mock-flow.
`DATA_SOURCE=mock` запрещён вне local, поэтому сам mobile guard корректен. Проблема — отсутствие
реального канала доставки для внешнего пользователя.

**Backend first:**

- интерфейс `OtpDeliveryProvider`;
- адаптер выбранного SMS gateway;
- идемпотентная отправка одного кода на живой challenge;
- метрики/лог результата без записи самого кода;
- тесты success, provider timeout, retry и rate limit;
- аналогичный flow для смены телефона.

**UI при отсутствии отдельного дизайна:** текущих экранов достаточно; нужны честная ошибка доставки,
таймер повторной отправки и disabled/busy состояния.

### Главная и shell-навигация

#### FNC-01 — «Пройти маршрут»

**Что видит пользователь:** основной CTA запуска маршрута.  
**Фактически:** показывается `Прохождение маршрута появится позже`.

Доказательство: `tourism-mobile/lib/routing/shell/app_shell_screen.dart:235-240`.

Backend-модуль `route_execution` содержит только `__init__.py` и не подключает router.

**Backend first — route execution v0:**

- сущность прохождения: user, route, status, started/finished timestamps;
- snapshot остановок на момент старта;
- `POST /route-executions`;
- `GET /route-executions/active`;
- `GET /route-executions` с пагинацией;
- `POST /route-executions/{id}/stops/{stop_id}/complete`;
- `POST /route-executions/{id}/complete` и `cancel`;
- BOLA, идемпотентность повторного complete, тесты переходов статуса;
- начисление Travel Points только после надёжной фиксации прохождения.

**Новый экран:** агент самостоятельно проектирует полноценный экран прохождения в стиле приложения:
название маршрута, список точек с checkbox, прогресс, кнопки «Отметить точку», «Завершить» и
«Отменить». GPS-навигация для v0 не нужна.

### Каталог мест

Каталог, поиск, фильтры, favorite и открытие карточки работают.

### Карточка места

#### FNC-07 — аудиогид и map pin

- Кнопка аудиогида показывает snackbar: `place_details_screen.dart:422-431`.
- Pin внутри preview карты получает пустой `onPinTap`: `place_details_screen.dart:787-805`.
- Share места работает, но фактически копирует название, адрес и координаты в clipboard; это не
  системный share sheet.

**Backend first для аудио:** модель аудиоматериала, duration, locale, public/auth URL, admin upload,
range requests и доступность материала в Place DTO.

**Новый UI:** полноценный audio player в текущем стиле приложения с play/pause, progress и duration.
При отсутствии audio
кнопку не показывать.

### Каталог маршрутов / swipe deck

#### FNC-10 — skip не сохраняется

`_handleSwipe` обрабатывает только `favorite`; для `skip` backend-вызова нет:
`tourism-mobile/lib/features/routes/presentation/routes_catalog_screen.dart:115-119`.

Карточка исчезает из текущей колоды, но решение не переживает новый запуск. Текст «на сегодня» не
соответствует реальной ежедневной подборке.

**Backend first:**

- таблицы recommendation deck и feedback;
- `GET /recommendations/today`;
- `POST /recommendations/{route_id}/skip`;
- защита от повторов и идемпотентность;
- host cron/CLI формирования колоды;
- fallback на обычный каталог при отсутствии колоды.

**Новый UI:** текущую swipe-вёрстку можно переиспользовать и развить в полноценную колоду с loading,
error и exhausted состояниями
для нового API.

### Карточка маршрута

#### FNC-06 — видимые действия без реализации

| Control | Фактическое поведение | Доказательство |
| --- | --- | --- |
| Поделиться | snackbar | `route_details_screen.dart:205` |
| Скачать офлайн | snackbar | `route_details_screen.dart:206` |
| Меню маршрута | snackbar | `route_details_screen.dart:227` |
| Аудиогид | snackbar | `route_details_screen.dart:274-279` |

Favorite, вкладки, отзывы, список остановок и выбор pin работают.

**Backend first:**

- share не требует backend: сформировать deep link и вызвать системный share sheet;
- offline зависит от offline manifest/version API;
- audio зависит от media contract, описанного в FNC-07;
- menu должен появляться только при наличии конкретных команд: report, hide, edit own route и т.п.

### Расчёт маршрута

#### FNC-04 — synthetic routing

Backend использует только `StubRoutingProvider`: haversine между точками, коэффициент `1.35`,
прямая WKT-линия и расчёт времени по фиксированной средней скорости.

Доказательства:

- `tourism-backend/src/tourism_backend/modules/route_builder/infrastructure/routing_stub.py:17-23`
- `tourism-backend/src/tourism_backend/modules/route_builder/infrastructure/routing_stub.py:40-102`
- `tourism-backend/src/tourism_backend/config.py:95-98`

Это допустимо для тестового конструктора, но не является дорожным маршрутом и не должно
показываться пользователю как навигационно точное расстояние.

**Backend first:** добавить provider adapter (OSRM/Valhalla/другой выбранный движок), circuit breaker,
timeout, fallback и явный `routing_quality`. До подключения показывать пользователю маркировку
«примерное расстояние».

### Подбор по параметрам и результаты

Match и deterministic generate работают через backend. Кнопки фильтра, открытия найденного
маршрута и генерации имеют реальные обработчики.

### AI-чат

#### FNC-08 — карта AI-предложения

Кнопка «Посмотреть карту» показывает сообщение о будущем обновлении:
`tourism-mobile/lib/features/route_match/presentation/route_match_screen.dart:584-590`.

**Backend first:** достаточно уже возвращаемой геометрии/остановок, но после FNC-04 контракт должен
явно содержать geometry, provider и quality. Затем нужен минимальный экран карты с polyline и pins.

#### FNC-14 — mock AI provider

Backend содержит `MockAIPlanningProvider`, который не выполняет сетевого обращения. Значения по
умолчанию: `AI_PLANNING_ENABLED=false`, `AI_PROVIDER=mock`.

Доказательства:

- `tourism-backend/src/tourism_backend/modules/route_builder/infrastructure/ai_mock.py:1-40`
- `tourism-backend/src/tourism_backend/config.py:80-90`

Mock полезен для local/tests, но staging/production должны явно запрещать mock provider при
`AI_PLANNING_ENABLED=true` либо показывать AI-функцию как недоступную.

### История AI-чатов

Список сессий и возобновление чата работают. Удаление сессий в UI и API отсутствует; так как control
не нарисован, это отдельная новая функция, а не no-op.

### Публикация маршрута

В API-режиме draft/publish flow подключён к backend. В local используется
`InMemoryRoutePublicationRepository`. Это ожидаемый dev mock.

Если понадобится отсутствующий экран backend-ошибки/модерации, достаточно временного списка
статусов и текстового блока причины отклонения.

### Избранное / Мои маршруты

#### FNC-09 — фальшивая история

Вкладка «История» строится как `routes.take(6)`, то есть показывает первые маршруты каталога:
`tourism-mobile/lib/features/my_routes/presentation/my_routes_screen.dart:149-153`.

**Backend first:** использовать `GET /route-executions`; поддержать пагинацию и статусы. После этого
вкладка может переиспользовать текущие карточки маршрутов, добавив дату и результат прохождения.

Favorite routes, favorite places и subscriptions работают через API.

### Профиль, достижения и leaderboard

#### FNC-13 — пустой refresh и слабое действие достижения

- Pull-to-refresh чужого профиля вызывает пустой async callback:
  `tourism-mobile/lib/features/profile/presentation/profile_screen.dart:208-216`.
- Нажатие на достижение в профиле и каталоге показывает только snackbar с названием.

Backend API достижений уже существует. Для минимального UI достаточно bottom sheet или простого
экрана: название, описание, статус, дата получения и прогресс, если backend его возвращает.

Refresh должен инвалидировать `publicProfileProvider(userId)` и achievements provider.

### Настройки

#### FNC-12 — «О сервисе»

Control показывает `Документация сервиса появится позже`:
`tourism-mobile/lib/features/settings/presentation/settings_screen.dart:57-69`.

Backend не требуется. Минимальный экран: версия приложения, ссылки на пользовательские документы,
политику конфиденциальности, контакты и licenses.

### Оффлайн маршруты

#### FNC-11 — настройки без скачивания

Переключатели меняют только локальный `SettingsPreferences`. Реального download job, manifest,
проверки версии и offline storage нет.

Доказательства:

- `tourism-mobile/lib/features/settings/presentation/settings_prefs_screens.dart:247-260`
- `tourism-mobile/lib/features/settings/application/settings_providers.dart:82-94`

«Очистить кэш» выполняет refresh API providers и меняет label; изображения и offline packages не
удаляются: `settings_prefs_screens.dart:278-287`.

**Backend first:**

- versioned offline manifest маршрута;
- список обязательных JSON/media объектов с size/checksum;
- права доступа и срок жизни приватных URL;
- ETag/Last-Modified;
- entitlement только если бизнес-правило действительно ограничивает объём.

**Минимальный UI:** список загрузок, размер, состояние, retry, delete; системный progress indicator.

### Поддержка

#### FNC-12 — разделы «позже»

- «Оценить приложение» — snackbar;
- «Вопросы по приложению» — snackbar;
- «Баллы ТревелПоинт и достижения» — snackbar.

Доказательство: `tourism-mobile/lib/features/settings/presentation/settings_support_screens.dart:82-90,115-133`.

FAQ «Маршруты и навигация» полностью hardcoded в mobile. Для первой версии это допустимо, но
контент нельзя обновлять без релиза приложения.

**Минимальный UI:** для FAQ можно оставить существующую вёрстку и добавить backend-managed JSON;
для Rate — открыть store review URL; если store listing ещё нет, скрыть control.

#### FNC-02 — форма «Ошибка на маршруте»

В форме всегда показываются четыре hardcoded маршрута `_mockReportRoutes`:
`settings_support_screens.dart:873-878`.

При submit выбранный маршрут добавляется только текстом в subject. `route_id`, который уже
поддерживает `SupportRepository` и backend schema, не передаётся:
`settings_support_screens.dart:1055-1062`.

**Backend first:** дополнительный endpoint не обязателен — можно использовать существующий список
маршрутов пользователя. Нужно определить продуктовый scope: published, authored, favorite или
recent execution. Для сообщения об ошибке логичнее recent/active executions с fallback на search.

**Новый UI:** полноценный searchable select реальных маршрутов в стиле формы поддержки, затем
существующие поля типа проблемы,
описания и вложений.

Чат поддержки, сообщения, polling и загрузка фотографий функциональны.

### Travel+

#### FNC-05 — mock checkout

Экран прямо объявлен mock checkout, содержит тестовые данные карты и не вызывает платёжный gateway:
`tourism-mobile/lib/features/settings/presentation/settings_travel_plus_checkout_screen.dart:16-36`.

Backend self-activation записывает подписку с `source=mock_checkout` и разрешена только в
local/test:
`tourism-backend/src/tourism_backend/modules/subscriptions/presentation/router.py:18-38`.

В активной подписке строка «Способ оплаты» выглядит интерактивной, но показывает snackbar:
`settings_travel_plus_screen.dart:234-250`.

**Backend first:** выбрать App Store / Google Play contract, серверную проверку receipt/token,
идемпотентные webhook events, entitlement reconciliation и restore purchases. Карточную форму в
mobile после этого удалить, если используется store billing.

## Backend gaps, не привязанные к отдельному готовому экрану

### Route execution

`tourism_backend.modules.route_execution` пуст. Это основной backend blocker для FNC-01, FNC-09 и
части достижений.

### Recommendations

Есть seasonal recommendation blocks внутри AI tool registry, но нет пользовательской сущности
ежедневной колоды, feedback API и cron. Не смешивать эти два понятия.

### Offline delivery

Есть entitlement `offline_favorites_extended`, но нет его функционального потребителя и offline API.
Не обещать платную offline-возможность до реализации manifest/download flow.

### Push/SMS semantics

FCM опционален; при отсутствии конфигурации остаются только in-app уведомления. SMS toggle
сохраняется, но SMS delivery отсутствует. Тексты UI не должны обещать внешнюю доставку, пока provider
не подключён.

### Документация backend

`tourism-backend/README.md:14-15` продолжает называть `route_builder` и `subscriptions` пакетами без
router. Фактически оба подключены в `tourism-backend/src/tourism_backend/api/v1/router.py:24,30`.
Единственная реальная package-заглушка из этой тройки — `route_execution`.

## Экраны без подтверждённых no-op элементов

При статическом сопоставлении UI handlers и repository/API вызовов новых заглушек не найдено в:

- Welcome;
- Главной ленте и «Смотреть все»;
- каталоге мест;
- параметрическом подборе и списке результатов;
- чате поддержки;
- форме ошибки приложения;
- экране благодарности;
- настройках имени, фото, телефона и предпочтений;
- входящих уведомлениях;
- leaderboard;
- списке достижений как read-only каталоге;
- создании и публикации маршрута в API-режиме;
- favorite/subscription действиях.

Это означает только отсутствие явного mock/no-op по статическому коду, а не полное UX или runtime
тестирование каждого состояния.

## Предлагаемый backend-first порядок

1. **BE-FNC-01: route execution v0** — закрывает главный пользовательский цикл и настоящую History.
2. **BE-FNC-02: route report binding** — реальные `route_id`, recent executions/search.
3. **BE-FNC-03: SMS delivery abstraction** — разблокирует внешний onboarding и смену телефона.
4. **BE-FNC-04: recommendations v1** — daily deck, persistent skip, cron.
5. **BE-FNC-05: offline manifest API** — затем download manager в mobile.
6. **BE-FNC-06: routing provider adapter** — после достаточного published-каталога.
7. **BE-FNC-07: audio media contract** — единообразно для places и routes.
8. **BE-FNC-08: billing verification** — после выбора store/payment provider.
9. **BE-FNC-09: managed FAQ/about content** — если контент должен меняться без mobile release.
10. Mobile-only cleanups: share sheet, public-profile refresh, achievement sheet, скрытие unavailable
    controls.

## Следующий шаг

Первый slice начат и зафиксирован в remediation plan:

- `BE-FNC-01` / R9 backend — реализовано в `tourism-backend` (route execution v0);
- `MO-FNC-01` — подключение CTA и экран прохождения остаются открытыми;
- `MO-FNC-02` — перевод вкладки «История» на реальные прохождения остаётся открытым.

Сопоставить каждый `FNC-*` / `BE-FNC-*` с фазами и ID из
`2026-08-27-review-remediation-plan.md`:

- уже запланировано и можно переиспользовать;
- запланировано частично и требует расширения acceptance criteria;
- отсутствует в плане и требует нового пункта;
- неактуально либо должно быть сознательно скрыто из UI.

После сопоставления начинать с первого независимого backend slice с миграцией, API schema,
service tests и минимальным mobile consumer.
