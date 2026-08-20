# Доменная модель

## Общие правила

- Идентификаторы имеют тип UUID, время хранится в UTC, координаты — в WGS 84.
- Публичные entities используют `status`, `createdAt`, `updatedAt`.
- Редакционные данные содержат `sourceName`, `sourceUrl`, `sourceCheckedAt`,
  `freshnessStatus` и при необходимости `expiresAt`.
- Значения `freshnessStatus`: `fresh`, `review_due`, `stale`, `unknown`.
- Удаление опубликованных данных предпочтительно заменяется архивацией.
- Связи между modules передаются через IDs и application contracts. Прямые
  cross-domain ORM imports запрещены.

## Geography

### Country

Назначение: верхний уровень географии, позволяющий платформе быть multi-country
и multi-region.

Поля:

- `id`, `code` ISO 3166-1 alpha-2, `name`, `slug`;
- `defaultLocale`, `timezone`, `status`;
- `sourceName`, `sourceUrl`, `sourceCheckedAt`, `freshnessStatus`;
- `createdAt`, `updatedAt`.

Связи: `Country` имеет много `Region`.

Module owner: `geography`.

Invariants:

- `code` и `slug` уникальны;
- timezone должна быть валидным IANA identifier;
- нельзя публиковать `Region` для архивной страны.

### Region

Назначение: административный или продуктовый регион внутри страны; первым
регионом является Республика Крым.

Поля:

- `id`, `countryId`, `name`, `slug`, `administrativeCode`;
- `timezone`, `centerPoint`, `boundary`;
- `status`, source и freshness fields, timestamps.

Связи: принадлежит `Country`, имеет много `Locality` и `Place`.

Module owner: `geography`.

Invariants:

- уникальный `slug` в пределах `Country`;
- `centerPoint` должен находиться в `boundary`, если boundary задана;
- опубликованный регион принадлежит опубликованной стране.

### Locality

Назначение: населённый пункт или именованная территория внутри региона.

Поля:

- `id`, `regionId`, опциональный `parentLocalityId`;
- `name`, `slug`, `type`, `postalCode`;
- `centerPoint`, опциональная `boundary`;
- `status`, source и freshness fields, timestamps.

Связи: принадлежит `Region`, может образовывать иерархию и иметь много `Place`.

Module owner: `geography`.

Invariants:

- родительская locality находится в том же регионе;
- циклы в иерархии запрещены;
- `slug` уникален в пределах региона;
- координаты должны попадать в region boundary, если она известна.

## Places

### Category

Назначение: управляемая классификация мест.

Поля:

- `id`, опциональный `parentCategoryId`;
- `code`, `name`, `slug`, `description`, `iconKey`;
- `sortOrder`, `status`, timestamps.

Связи: имеет иерархию и many-to-many связь с `Place`.

Module owner: `places`.

Invariants:

- `code` и `slug` уникальны;
- циклы категорий запрещены;
- архивную категорию нельзя назначить новому месту.

### Place

Назначение: туристический объект, природная локация, музей, сервисная точка или
другая цель посещения.

Поля:

- `id`, `regionId`, опциональный `localityId`;
- `name`, `slug`, `shortDescription`, `description`;
- `location`, `address`, `contactPhone`, `websiteUrl`;
- `accessibility`, `recommendedEquipment`, `seasonality`, `difficulty`;
- `isPaid`, `priceNotes`, `isSuitableForChildren`;
- `safetyWarnings`, `temporaryClosureStatus`, `temporaryClosureReason`;
- `closedFrom`, `closedUntil`, `publicationStatus`;
- source и freshness fields, timestamps.

Связи: принадлежит `Region`, опционально `Locality`, имеет категории,
`PlaceEntrance`, `PlaceSchedule`, `PlaceImage`; используется остановками,
избранным и генератором.

Module owner: `places`.

Invariants:

- locality, если задана, принадлежит тому же region;
- опубликованное место имеет имя, координаты, минимум одну категорию и источник;
- `closedUntil` не раньше `closedFrom`;
- закрытое место не предлагается route builder без явного override;
- safety warnings и equipment не заменяются маркетинговым описанием;
- stale критичные данные помечаются пользователю и могут исключать генерацию.

### PlaceEntrance

Назначение: конкретная точка входа, подъезда или начала посещения, необходимая
для корректной навигации вместо маршрута к геометрическому центру места.

Поля:

- `id`, `placeId`, `name`, `location`, `addressHint`;
- `entranceType`, `isPrimary`, `accessibility`;
- `vehicleRestrictions`, `openingNotes`, `status`;
- source и freshness fields, timestamps.

Связи: принадлежит одному `Place`; может выбираться route stop.

Module owner: `places`.

Invariants:

- у опубликованного place не более одного primary entrance;
- активный entrance имеет координаты;
- ограничения транспорта не должны противоречить accessibility metadata.

### PlaceSchedule

Назначение: регулярные часы работы, сезонные интервалы и исключения.

Поля:

- `id`, `placeId`, опциональный `placeEntranceId`;
- `scheduleType`, `validFrom`, `validUntil`, `timezone`;
- `weekdays`, `opensAt`, `closesAt`, `isClosed`;
- `exceptionDate`, `note`, `status`;
- source и freshness fields, timestamps.

Связи: принадлежит `Place` и опционально конкретному `PlaceEntrance`.

Module owner: `places`.

Invariants:

- интервал validity корректен и timezone совпадает с географией места;
- exception имеет приоритет над регулярным расписанием;
- пересекающиеся правила одинакового приоритета запрещены;
- `isClosed` не содержит часы открытия;
- временное закрытие place имеет приоритет над schedule.

### PlaceImage

Назначение: метаданные лицензированного изображения места.

Поля:

- `id`, `placeId`, `mediaAssetId`, `kind`, `altText`;
- `author`, `license`, `sourceUrl`, `capturedAt`;
- `sortOrder`, `isCover`, `status`, timestamps.

Связи: принадлежит `Place`, ссылается на asset в module `media`.

Module owner: `places`; бинарный asset принадлежит `media`.

Invariants:

- опубликованное изображение имеет `altText`, автора или источник и лицензию;
- у места не более одной cover image;
- нельзя публиковать media с неподтверждёнными правами использования.

## Routes

Целевая модель — единый `Route` с дискриминатором источника. Исторические имена
`PreparedRoute` / `GeneratedRoute` в ранних черновиках считаются синонимами
`Route(source=editorial)` и `Route(source=generated)`.

### Route

Назначение: упорядоченный набор точек и геометрия перемещения между ними.

Поля:

- `id`, `regionId`, опциональный `ownerUserId`;
- `name`, `slug`, `shortDescription`, `description`;
- `source`: `editorial` | `generated` | `user_created`;
- `visibility`: `private` | `unlisted` | `public`;
- `lifecycleStatus`: `draft` | `active` | `archived`;
- `moderationStatus` (будущее): `not_submitted` | `pending` | `approved` |
  `rejected` | `changes_requested`;
- `estimatedDurationMinutes`, `distanceMeters`, `difficulty`, `budgetNotes`;
- `seasonality`, `transportMode`, `isRoundTrip`;
- `suitableForChildren`, `petsAllowed`, `accessibility`;
- `geometry`, `authorLabel`, `sourceName`, `sourceUrl`;
- category links, source/freshness fields для editorial, timestamps.

Связи: принадлежит `Region`, содержит `RouteStop`; может иметь
`RouteExecution`; в будущем ссылается из `TripItem`.

Module owner: `routes` (editorial/user_created persistence); `route_builder`
создаёт `source=generated`.

Invariants:

- active public editorial имеет минимум две остановки;
- generated и user_created в MVP — private;
- прогресс прохождения не меняет `lifecycleStatus` маршрута;
- stale editorial отмечается или снимается с выдачи.

### RouteStop

Назначение: упорядоченная остановка маршрута.

Поля:

- `id`, `routeId`, `placeId`, опциональный `placeEntranceId`;
- `position`, `visitDurationMinutes`, `note`, `isOptional`;
- для generated: `arrivalAt`, `departureAt`, leg metrics, `selectionReason`;
- timestamps.

Module owner: тот же, что у родительского `Route` write-path.

Invariants:

- `position` уникальна и непрерывна;
- entrance принадлежит place;
- закрытая обязательная остановка блокирует публикацию editorial.

### RouteGenerationRequest

Назначение: нормализованный набор пользовательских условий генерации.

Поля:

- `id`, опциональный `userId`, `regionId`, `localityIds`;
- `origin`, опциональный `destination`, `returnToOrigin`;
- `startsAt`, `minDurationMinutes`, `maxDurationMinutes`;
- `maxDistanceMeters`, `minPlaceCount`, `maxPlaceCount`, `transportMode`;
- `categoryIds`, `requiredPlaceIds`, `excludedPlaceIds`, `priorityPlaceIds`;
- `pricePreference`, `withChildren`, `petsAllowed`, `accessibilityNeeds`;
- `equipmentAvailable`, `difficulty`, `season`, `preferences`;
- `status`, `failureCode`, timestamps.

Связи: порождает ноль или несколько `Route(source=generated)`.

Module owner: `route_builder`.

Invariants:

- min ≤ max для duration/distance/place count;
- required и excluded не пересекаются;
- при `returnToOrigin=true` destination не задаётся;
- идемпотентность по request ID;
- `failureCode` примеры: `no_candidates`, `constraints_too_strict`,
  `routing_provider_error`, `route_too_long`, `invalid_start_point`,
  `quota_exceeded`.

## Route execution

### RouteExecution

Назначение: конкретное прохождение маршрута пользователем.

Поля:

- `id`, `userId`, `routeId` и/или immutable `routeSnapshot`;
- `status`: `planned` | `in_progress` | `paused` | `completed` | `cancelled`;
- `startedAt`, `completedAt`;
- `currentStopIndex`, `visitedStops`, `skippedStops`, `progressPercent`;
- опционально `lastKnownPosition`;
- `createdAt`, `updatedAt`.

Module owner: `route_execution`.

Invariants:

- статусы маршрута и execution независимы;
- доступ только у владельца execution;
- completed имеет `completedAt` и progress 100% либо явный partial-complete
  policy (зафиксировать в API).

## Trip (будущий модуль)

Таблицы и API Trip в MVP не создаются. Целевая структура:

- `Trip` → `TripDay` → `TripItem`;
- `TripItem` может ссылаться на `Route`, `Place`, Accommodation, Transport,
  Restaurant, Note, CustomEvent.

`Route.id` должен оставаться стабильной ссылкой для будущего `TripItem`.

## Subscriptions / Travel+ (foundation)

Концепты: `Plan`, `Subscription`, `Entitlement`, `UsageCounter`,
`QuotaPolicy`. As-built: `users.travel_plus_*` + таблица
`travel_plus_subscriptions`; проверки квот — через `EntitlementService`.
Канон AI/подбора: [ai-route-chat-product-contract.md](ai-route-chat-product-contract.md).
Store billing — позже.

## Identity и users

### User

Назначение: учётная запись и состояние идентификации.

Поля:

- `id`, `emailNormalized`, `passwordHash` или внешний identity reference;
- `status`, `emailVerifiedAt`, `lastLoginAt`;
- `createdAt`, `updatedAt`, `deletedAt`.

Связи: имеет один `UserProfile`, избранное и сохранённые маршруты.

Module owner: `identity`.

Invariants:

- normalized email уникален среди активных accounts;
- plaintext password никогда не сохраняется;
- заблокированный или удалённый user не получает новые sessions;
- identity module не раскрывает credential fields другим modules.

### UserProfile

Назначение: персональные настройки без credential data.

Поля:

- `id`, `userId`, `displayName`, `preferredLocale`;
- `homeRegionId`, `accessibilityNeeds`, `travelPreferences`;
- `createdAt`, `updatedAt`.

Связи: принадлежит `User`, ссылается на home region по ID.

Module owner: `users`.

Invariants:

- у user ровно один профиль;
- locale поддерживается приложением;
- profile не хранит password, tokens или provider credentials.

### FavoritePlace

Назначение: пользовательская закладка на место.

Поля:

- `id`, `userId`, `placeId`, опциональный `note`, `createdAt`.

Связи: связывает `User` и `Place` по IDs.

Module owner: `users`.

Invariants:

- пара `userId + placeId` уникальна;
- ссылка на архивное место сохраняется для истории, но явно помечается;
- доступ к записи имеет только владелец.

### SavedRoute

Назначение: пользовательское сохранение маршрута с названием и snapshot.

Поля:

- `id`, `userId`, `routeId`;
- `name`, `snapshot`, `savedAt`, `updatedAt`.

Связи: принадлежит `User`; ссылается на `Route` по ID.

Module owner: `favorites` / `users`.

Invariants:

- snapshot неизменяем и не содержит credentials;
- изменения исходного маршрута не переписывают пользовательскую историю;
- доступ имеет только владелец.

## Границы modules

- `identity`: credentials, sessions и account lifecycle.
- `users`: profile.
- `geography`: country, region и locality.
- `places`: category, place, entrance, schedule и image metadata.
- `routes`: route persistence (editorial/user_created) и read models.
- `route_builder`: generation requests, generated routes, RoutingProvider.
- `route_execution`: прохождения маршрутов.
- `favorites`: favorite places и saved routes.
- `subscriptions`: plans, entitlements, usage counters.
- `media`: binary assets, storage и transformations.

Каждый module владеет своей persistence model и публикует application API,
domain events или read contracts. Join между modules выполняется по IDs на
application layer, а не через ORM navigation properties.
