# Push-уведомления (FCM) — план подключения

Канонический статус: **in-app inbox уже работает на iOS и Android**
(API `/me/notifications` + UI). Системные баннеры (tray) — через
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
- Approve отзыва создаёт in-app notification; FCM send включается, когда
  на бэкенде задан `FCM_SERVICE_ACCOUNT_JSON` (или путь к файлу).

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
4. Xcode → Runner → Signing & Capabilities:
   - **Push Notifications**
   - **Background Modes** → Remote notifications
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

- `FCM_SERVICE_ACCOUNT_JSON` (весь JSON одной строкой/env), или
- `FCM_SERVICE_ACCOUNT_FILE` (путь к файлу на сервере)

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
| Тап по push | Deep link `target_type`/`target_id` → экран маршрута (как inbox) |
