# Push-уведомления (FCM) — план подключения

Канонический статус: **in-app inbox уже работает на iOS и Android**
(API `/me/notifications` + UI, бейдж на колокольчике и foreground-тост
при открытом приложении). Системные баннеры (tray) — через
**Firebase Cloud Messaging**.

Официальный старт: [FCM для Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## Почему Firebase сейчас

- Клиентский FCM на Spark **бесплатен** для обычных пушей.
- Платный отдельно: **Apple Developer** (~$99/год) для APNs на реальных iPhone.
- Серверный ключ / service account **не коммитим** — только CI/secret manager.

## Что уже в коде

- Таблица / API `device_tokens` — регистрация FCM token с устройства.
- Mobile: `firebase_core` + `firebase_messaging`, bootstrap **не падает**,
  если Firebase ещё не сконфигурирован (`AppPush.isConfigured == false`).
- iOS: в `pubspec.yaml` отключён Flutter Swift Package Manager
  (`enable-swift-package-manager: false`) — плагины идут через CocoaPods
  (иначе Xcode ломается на путях вроде `image_picker_ios-0.8.13+6`).
  Deployment target **iOS 15+** (требование Firebase SDK 12.x).
- iOS target уже содержит capability **Push Notifications**,
  `Runner.entitlements` и Background Mode `remote-notification`. Для реальной
  Клиентский `GoogleService-Info.plist` уже добавлен локально; для реальной
  доставки всё ещё нужен Apple Developer membership и APNs key в Firebase.
- Approve/reject маршрута и отзыва создают in-app notification автору
  (`route_published` / `route_rejected` / `review_published` /
  `review_rejected`); approve чужого отзыва — ещё `route_review` владельцу.
  Лайк профиля (подписка) — `profile_like` получателю. FCM send включается,
  когда на бэкенде задан `FCM_SERVICE_ACCOUNT_JSON` (или путь к файлу).
- Опубликованный ответ на отзыв создаёт `review_reply` автору исходного
  комментария; до прохождения модерации уведомление не отправляется.
- Ответ оператора поддержки создаёт `support_reply` в inbox и отправляет FCM;
  foreground-сообщение сразу обновляет inbox, тап открывает чат поддержки.

## Что сделать руками (пошагово, один раз)

`DefaultFirebaseOptions.configured` включается **по платформе**: Android —
когда заполнены реальные options (уже из `google-services.json` проекта
`crimeatrip-41d24`); iOS — после `GoogleService-Info.plist` / заполнения
ios-options. Пока для платформы placeholder — `getToken()` не вызывается.

### A. Создать проект Firebase

1. Открой [console.firebase.google.com](https://console.firebase.google.com/)
   под своим Google-аккаунтом.
2. **Add project** / «Создать проект» → имя, например `crimeatrip`.
3. Google Analytics можно выключить (для FCM не обязателен).
4. Дождись создания → **Continue**.

### B. Добавить Android-приложение

1. На overview проекта: иконка Android → Add app.
2. **Android package name** (строго): `com.crimeatravel.tourism_mobile`
3. Download `google-services.json` → положи в
   `tourism-mobile/android/app/google-services.json`.
4. В Gradle раскомментируй/включи plugin `com.google.gms.google-services`
   (комментарии уже есть в `android/settings.gradle.kts` и
   `android/app/build.gradle.kts`).

### C. Добавить iOS-приложение

1. На overview: иконка Apple → Add app.
2. **iOS bundle ID** (строго): `com.crimeatravel.tourismMobile`
   (с CamelCase `tourismMobile` — как в Xcode, не как Android).
3. Download `GoogleService-Info.plist` →
   `tourism-mobile/ios/Runner/GoogleService-Info.plist`
   (и добавь файл в target Runner в Xcode, если не подхватился).
4. Xcode → Runner → Signing & Capabilities: проверь уже добавленные
   **Push Notifications** и **Background Modes → Remote notifications**.
5. Firebase Console → Project settings → Cloud Messaging →
   **Apple app configuration**: загрузи APNs Authentication Key
   (`.p8` из [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)
   → Keys → Key with Apple Push Notifications service).
   Без этого на реальном iPhone `getToken()` не заработает.

### D. Сгенерировать `firebase_options.dart`

Из каталога `tourism-mobile/`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Выбери созданный Firebase-проект и платформы Android + iOS.
Файл `lib/firebase_options.dart` перезапишется — после этого верни
геттер `configured` (true, если `apiKey != 'REPLACE_ME'` для текущей
платформы), либо снова заполни options вручную из plist/json. Без
реальных ios/android options `getToken()` не вызывается.

### E. Backend (отправка пушей)

В Firebase Console → Project settings → Service accounts →
**Generate new private key**. Содержимое JSON — только в секрет деплоя:

- `FCM_SERVICE_ACCOUNT_JSON` (весь JSON одной строкой в server `.env`), или
- `FCM_SERVICE_ACCOUNT_FILE` (путь к файлу на сервере)

На test-контуре переменная пробрасывается через
`tourism-platform/deploy/test/compose.yaml` → backend container.
Сниппет `firebase_admin.initialize_app(...)` **не нужен** — бэкенд шлёт
FCM HTTP v1 через `google-auth` + `httpx`
(`modules/notifications/application/fcm.py`).

**Никогда не коммить** service account. Клиентские
`google-services.json` / `GoogleService-Info.plist` обычно можно в Git.

### F. Проверка, что токен появился

1. Пересобери приложение, залогинься.
2. Настройки → включи «Пуш-уведомления» (должен исчезнуть snackbar про
   «после настройки Firebase»).
3. Клиент вызовет `FirebaseMessaging.getToken()` и отправит токен на
   `POST /api/v1/me/device-tokens`.
4. В БД / логах API должен появиться `device_tokens` для пользователя.

## Поведение продукта

| Слой | Когда |
| --- | --- |
| In-app inbox | Всегда при событии (например, опубликован отзыв) |
| System push | Если у пользователя `notify_push_enabled`, есть device token, и FCM настроен |
| Тап по push | Deep link `target_type`/`target_id` → маршрут / профиль / достижение / чат поддержки |

## Почему in-app есть, а Firebase tray нет

In-app inbox **не зависит** от FCM. Системный баннер Android/iOS идёт
только через `maybe_push_notification` → FCM HTTP v1. Типичные причины:

1. **На сервере нет service account** — без `FCM_SERVICE_ACCOUNT_JSON` или
   `FCM_SERVICE_ACCOUNT_FILE` бэкенд пишет `fcm_skipped_no_service_account`
   и **молча** не шлёт tray (inbox при этом создаётся). Это самый частый
   блокер на stage/prod.
2. **Нет строки в `device_tokens`** — клиент регистрирует токен при логине
   (если «Пуш-уведомления» включены) и при переключении тумблера в
   настройках. Проверь: `SELECT user_id, platform, left(token,12), updated_at
   FROM device_tokens ORDER BY updated_at DESC LIMIT 20;`.
3. **`notify_push_enabled = false`** у пользователя.
4. **Android 13+**: отказ в `POST_NOTIFICATIONS` → `getToken`/permission
   denied; в настройках ОС для приложения уведомления должны быть On.
5. **Package / Firebase project mismatch** — APK `applicationId`
   `com.crimeatravel.tourism_mobile` должен совпадать с
   `google-services.json` (сейчас проект `crimeatrip-41d24`).
6. Приложение **на переднем плане**: системный баннер FCM на Android часто
   не рисуется (это нормально) — смотри tray при свёрнутом приложении;
   in-app тост/бейдж при открытом приложении — отдельный путь.
7. **Backend без egress** — в `deploy/test/compose.yaml` сеть `private`
   `internal: true`. Backend должен быть ещё и в `edge`, иначе
   `oauth2.googleapis.com` / FCM недоступны (`fcm_oauth_failed` /
   ConnectError), а inbox при этом создаётся. Postgres/Redis остаются
   только в `private`.

### Быстрая проверка на сервере

```bash
# после деплоя service account + egress
# в логах API при approve отзыва/маршрута должно быть fcm_send_ok,
# а не fcm_skipped_no_service_account / fcm_oauth_failed / fcm_send_failed
```

FCM sender использует **PyJWT + httpx** (без пакета `requests` /
`google.auth.transport.requests`).

Firebase Console → Project settings → Service accounts →
**Generate new private key** → положить JSON в секрет деплоя
(`FCM_SERVICE_ACCOUNT_JSON` целиком или файл + `FCM_SERVICE_ACCOUNT_FILE`).
`project_id` в JSON должен быть `crimeatrip-41d24` (тот же, что у APK).
