# 2ГИС: Static API, Routing API и Flutter SDK — уточнение интеграции

Дата проверки: 2026-08-29. Источники — официальная документация 2ГИС:

- [Static API](https://docs.2gis.com/en/maps/others/static/overview)
- [Routing API](https://docs.2gis.com/en/api/navigation/routing/overview)
- [Flutter SDK](https://docs.2gis.com/flutter/sdk/overview)
- [Flutter SDK: начало работы](https://docs.2gis.com/flutter/sdk/start)
- [Flutter SDK: релизы](https://docs.2gis.com/en/flutter/sdk/releases/latest)

## Вывод

У проекта есть три разных контура доступа, которые нельзя смешивать:

| Контур | Назначение | Ключ | Статус |
| --- | --- | --- | --- |
| HTTP Static API | PNG-превью карты с точками, линиями и полигонами | HTTP API key | Можно использовать текущий demo-ключ |
| HTTP Routing API | Построение автомобильных и пешеходных маршрутов, geometry, время, высоты, фильтры | HTTP API key | Backend-адаптер уже реализован |
| Flutter SDK Full | Интерактивная карта, поиск, маршруты, navigator, voice и offline-пакеты | отдельный `dgissdk.key` из активной подписки | Пока не получен |

Бесплатный demo-ключ HTTP API не является ключом Mobile SDK. В официальной
документации указано, что demo-ключи недоступны для Mobile SDK; для SDK нужно
создать ключ доступа в активной подписке и скачать `dgissdk.key`. Для offline
данных нужен App ID. HTTP-ключ никогда не добавляется в Flutter bundle.

## Что используем сейчас

### Routing API на backend

Для обычных маршрутов используем endpoint:

```text
POST https://routing.api.2gis.com/routing/7.0.0/global?key=API_KEY
```

Backend передаёт тип транспорта, промежуточные точки, подробный output,
фильтры, пробки и `need_altitudes` для пеших маршрутов. Ответ сохраняется в
нашу route revision/snapshot и проходит собственные quality gates. Поэтому
2ГИС даёт дорожную geometry, но не отменяет наши проверки переправ, троп,
уклонов, закрытий и сезонной доступности.

Demo-ограничение длины маршрута — 50 км. Для одного запроса разрешено до 5
точек для пешего маршрута и до 10 для остальных типов. Запросы с несколькими
парами точек тарифицируются по каждой паре. Повторные вызовы и массовый
enrichment запрещены в CI.

### Static API как первый мобильный срез

Static API возвращает PNG и подходит для preview, но не заменяет интерактивную
карту, GPS или навигатор. Чтобы не раскрывать ключ и не расходовать квоту при
каждом открытии экрана, добавляем backend-прокси:

```text
GET /api/v1/maps/static/route/{route_id}?width=880&height=420&scale=2
GET /api/v1/maps/static/place/{place_id}?width=880&height=420&scale=2
```

Контракт прокси:

- ответ `image/png`, `Cache-Control` и `ETag`;
- ключ 2ГИС хранится только на backend;
- route preview строится из утверждённой route revision/GeoJSON;
- place preview строится из координат опубликованного места;
- размеры, zoom и количество объектов ограничиваются сервером;
- cache key включает объект, revision, width, height, scale и style;
- `401/403/404/429` не раскрывают URL или ключ 2ГИС;
- ambiguous/unpublished/closed объект не попадает в изображение;
- в приложении при недоступности Static API остаётся локальный geometry-preview.

Static API тарифицируется по успешным загрузкам изображений. Поэтому мобильный
клиент не должен запрашивать новую картинку на каждый rebuild или скролл:
нужны image cache, debounce и повторная загрузка только при смене revision или
размера.

## Полноценная мобильная карта

Официальный Flutter SDK означает, что отдельный самописный iOS/Android bridge
не является обязательным. Пакет подключается в `pubspec.yaml`:

```yaml
dependencies:
  dgis_mobile_sdk_full: ^13.6.0
```

Версия Full предоставляет карту, поиск, построение маршрутов, navigator и
offline-данные. Версия Map предоставляет карту и поиск, но не маршруты и
навигацию. Full и Map нельзя подключать одновременно.

Для SDK нужно:

1. получить отдельный `dgissdk.key` для активной подписки;
2. определить App ID для iOS и Android, если нужны offline-пакеты;
3. хранить ключ в assets только через защищённый release secret flow;
4. инициализировать один глобальный `DGis` context;
5. получить права на offline-территории у 2ГИС и загрузить их через
   `TerritoryManager`;
6. проверить размер приложения, разрешения геолокации, privacy и attribution.

## Архитектурное решение КРЫМТРИП

```text
Backend Routing API
  → route revision + quality gate + GeoJSON
  → Mobile Route Details / Active Route

Backend Static API proxy
  → PNG preview для текущего UI и offline snapshot

Flutter SDK Full (после отдельного SDK key)
  → интерактивная карта, GPS, navigator, voice, offline map/routing
```

Backend остаётся источником истины для выбранного маршрута и его safety status.
SDK используется как визуальный и навигационный слой. Нельзя молча заменять
утверждённую backend geometry маршрутом, который мобильный SDK построил иначе.

## Acceptance criteria

### Static preview

- маршрут и место показывают реальную картографическую подложку 2ГИС;
- маркеры и route line соответствуют опубликованным координатам/revision;
- ключ отсутствует в mobile logs, bundle и URL, видимом клиенту;
- повторное открытие использует cache и не создаёт лишний запрос;
- при offline/429/5xx работает локальный fallback;
- добавлены widget/API tests без вызова 2ГИС.

### Flutter SDK Full

- iOS и Android smoke на одной закреплённой версии SDK;
- карта, stop markers и approved route line отображаются;
- permission-denied, no-network и SDK-key errors имеют понятные состояния;
- навигация запускается только после quality gate и согласия на геолокацию;
- offline package удаляется пользователем и не смешивается с route snapshot;
- CI не вызывает 2ГИС и не требует vendor key.

## Очередь работ

1. Cursor реализует backend Static API proxy с указанным контрактом и
   server-side cache.
2. Mobile подключает `StaticMapPreview` с fallback на существующий
   `RouteMapPreview` и использует его в Route Details, Place Details и Active
   Route.
3. После получения `dgissdk.key` делаем короткий Flutter SDK spike на Full.
4. После device smoke подключаем интерактивную карту, затем navigator и
   offline-territories.

До получения SDK-ключа нельзя считать Mobile SDK или полноценную offline-карту
готовыми, но Static API preview и backend Routing API можно тестировать уже с
текущим HTTP demo-ключом в рамках квоты.
