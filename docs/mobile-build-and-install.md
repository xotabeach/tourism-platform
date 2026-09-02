# Mobile: сборка и установка (iOS / Android)

Инструкция для локальной сборки CrimeaTrip (`tourism-mobile`) с mock или
реальным API. Каноничный конфиг приложения:
`tourism-mobile/lib/core/config/app_config.dart`.

Рабочая директория для всех команд ниже:

```bash
cd tourism-mobile
flutter pub get
flutter devices   # список телефонов / симуляторов / Chrome
```

Текущий тестовый API: **`https://201-24-55-130.sslip.io`** (новый сервер, 8ГБ, Москва).

> **Сменился 2026-09-02.** Раньше был `https://86-106-20-132.sslip.io`. Адрес
> **вшивается в сборку** через `--dart-define=API_BASE_URL`, а `sslip.io` кодирует IP
> прямо в имени — поэтому уже установленные сборки продолжают ходить на старый сервер,
> пока их не пересоберут с новым адресом. Старый контур для этого пока оставлен живым.
> Ход переезда — [server-migration-runbook-2026-09-02.md](server-migration-runbook-2026-09-02.md).
>
> На неделе покупается нормальный домен — после перехода на него адрес перестанет быть
> привязан к IP, и следующий переезд будет сменой A-записи без пересборки приложения.
> Значение по умолчанию здесь и в `build-signed-apk.sh` тогда меняется один раз.

Адрес одинаково задаётся и для Android, и для iOS — это обычный `--dart-define`,
отдельной iOS-настройки нет (см. §«Сборка iOS» ниже, там тот же флаг).

---

## 1. Dart-define параметры приложения

Передаются как `--dart-define=KEY=value` в `flutter run` / `flutter build`.

| Ключ | Значения | По умолчанию | Правила |
| --- | --- | --- | --- |
| `APP_ENV` | `local` \| `test` \| `staging` \| `production` (`prod` = то же) | debug → `local`; **release без флага → `production`** | Имя приложения в UI зависит от env. `prod` — алиас; иное значение в release даёт серый экран |
| `DATA_SOURCE` | `mock` \| `api` | local → `mock`; иначе → `api` | `mock` **только** при `APP_ENV=local` |
| `API_BASE_URL` | абсолютный URL без credentials | local → `http://localhost:8000`; иначе **обязателен** | Для `test`/`staging`/`production` только **HTTPS**; host не может быть `*.example.com` |

### Типовые комбинации

```bash
# UI без сети (mock)
--dart-define=APP_ENV=local \
--dart-define=DATA_SOURCE=mock

# Local + свой backend (Compose на Mac)
--dart-define=APP_ENV=local \
--dart-define=DATA_SOURCE=api \
--dart-define=API_BASE_URL=http://localhost:8000
# На физическом устройстве localhost = сам телефон.
# Используй IP Mac в LAN, например http://192.168.1.10:8000

# Тестовый контур (то, чем обычно пользуемся на iPhone)
--dart-define=APP_ENV=test \
--dart-define=DATA_SOURCE=api \
--dart-define=API_BASE_URL=https://201-24-55-130.sslip.io

# Staging / production — тот же набор, другой URL и APP_ENV
--dart-define=APP_ENV=staging \
--dart-define=DATA_SOURCE=api \
--dart-define=API_BASE_URL=https://staging-api.example.org
```

Release **без** `APP_ENV` стартует как `production` и упадёт без валидного
HTTPS `API_BASE_URL`.

---

## 2. Полезные флаги Flutter CLI

Общие для `run` / `build` (неполный список, самые нужные):

| Флаг | Назначение |
| --- | --- |
| `-d <deviceId>` | Устройство (`flutter devices`) |
| `--debug` | Debug (hot reload). По умолчанию для `flutter run` |
| `--profile` | Profile mode |
| `--release` | Release (без hot reload) |
| `--dart-define=K=V` | Compile-time константа (см. выше) |
| `--dart-define-from-file=path.json` | Пачка defines из JSON (если удобнее) |
| `--no-pub` | Не вызывать `pub get` перед сборкой |
| `--build-name=x.y.z` | versionName / CFBundleShortVersionString |
| `--build-number=N` | versionCode / CFBundleVersion |

Только `flutter run`:

| Флаг | Назначение |
| --- | --- |
| `--hot` / `--no-hot` | Hot reload (в debug) |
| `r` / `R` / `q` в терминале | reload / restart / quit |

Только iOS build:

| Флаг | Назначение |
| --- | --- |
| `--simulator` | Сборка под Simulator (не на телефон) |
| `--no-codesign` | Без подписи (не ставится на device как есть) |
| `--codesign` | С подписью (нужен Apple team / Xcode) |

Только Android build:

| Флаг | Назначение |
| --- | --- |
| `--split-per-abi` | Отдельные APK по ABI (меньше размер) |
| `--target-platform=android-arm,android-arm64,android-x64` | Платформы |
| `--obfuscate --split-debug-info=build/symbols` | Обфускация Dart (release) |

---

## 3. iPhone: debug (live / hot reload) + API

Телефон по USB, разблокирован, Developer Mode включён.

```bash
cd tourism-mobile

# узнать id
flutter devices

flutter run -d 00008140-001A7D0C2668801C \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
```

В терминале: `r` hot reload, `R` hot restart, `q` выход.

Браузер (быстрые UI-правки, не 1:1 с iOS):

```bash
flutter run -d chrome \
  --dart-define=APP_ENV=local \
  --dart-define=DATA_SOURCE=mock
```

---

## 4. iPhone: release-сборка и установка + API

### Вариант A — одной командой (подпись через Xcode / automatic signing)

```bash
cd tourism-mobile

flutter run -d 00008140-001A7D0C2668801C --release \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
```

### Вариант B — `build` + `devicectl` (как в агентских сессиях)

```bash
cd tourism-mobile

flutter build ios --release \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io

# DEVICE = UDID из `xcrun devicectl list devices` или `flutter devices`
DEVICE=00008140-001A7D0C2668801C

xcrun devicectl device install app \
  --device "$DEVICE" \
  build/ios/iphoneos/Runner.app

xcrun devicectl device process launch \
  --device "$DEVICE" \
  com.crimeatravel.tourismMobile
```

Замечания:

- Для device нужен валидный Apple signing (team в Xcode → Runner).
- `--no-codesign` даёт `.app`, который на физический iPhone обычно **не** ставится.
- Bundle id iOS: `com.crimeatravel.tourismMobile`.

---

## 5. Android: debug / run + API

```bash
cd tourism-mobile
flutter devices

flutter run -d <android-device-id> \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
```

Application id: `com.crimeatravel.tourism_mobile`.

---

## 6. Android: подписанный APK / AAB + API

### 6.0. Проще всего — скрипт

Один раз нужен `android/key.properties` (см. §6.1). У тебя он уже может
лежать локально (файл в `.gitignore`). Дальше:

```bash
cd tourism-mobile

# release APK на test API (дефолт)
./scripts/build-signed-apk.sh

# сразу поставить на телефон по USB
./scripts/build-signed-apk.sh --install

# свой API / env
./scripts/build-signed-apk.sh \
  --env staging \
  --api-url https://staging-api.example.org \
  --install

# AAB для Google Play
./scripts/build-signed-apk.sh --aab --env production --api-url https://api.example.org
```

Готовый файл:

```text
build/app/outputs/flutter-apk/app-release.apk          # сырой артефакт Flutter
dist/CrimeaTrip-test-api.apk                           # копия с понятным именем
```

Имя в `dist/` строится как `CrimeaTrip-<APP_ENV>-<DATA_SOURCE>.apk`
(например `CrimeaTrip-test-api.apk`). Скрипт сам проверит `key.properties`
и путь к `.jks`, прокинет `APP_ENV` / `DATA_SOURCE` / `API_BASE_URL`,
соберёт **release + signing**.

### 6.0.1. CI: скачать APK из GitLab

На ветках `main` / `gamma` job `mobile-apk-test` собирает тот же signed
test APK и публикует **Job Artifact** (14 дней). В **lean** CI (default)
job только **manual**; в full (`CI_PIPELINE_MODE=full`) — как в
[ci-and-runners.md](ci-and-runners.md). Скачать: Pipeline → job
`mobile-apk-test` → Artifacts → `dist/CrimeaTrip-test-api.apk`.

Нужные **CI variables** на проекте `tourism-mobile` (masked / protected):

| Variable | Meaning |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0` (or `-i` on macOS) of the `.jks` |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |
| `ANDROID_STORE_PASSWORD` | keystore password |
| `MOBILE_TEST_API_BASE_URL` | HTTPS test API (e.g. `https://….sslip.io`) |

Prepare helpers: `scripts/ci-prepare-android-signing.sh` (writes ephemeral
`android/key.properties` + `ci-upload.jks`, removed after build). Keystore
is **never** an artifact. Without signing vars the job is manual /
skipped — pipeline style/tests still green.

### 6.1. Подготовить keystore (один раз)

Нужно только если ещё нет `android/key.properties` и `.jks`.

```bash
# пример путей — свои значения, НЕ коммить в git
mkdir -p "$HOME/.crimeatrip-signing"

keytool -genkey -v \
  -keystore "$HOME/.crimeatrip-signing/tourism-mobile-upload.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias crimeatrip
```

Создать `tourism-mobile/android/key.properties` (файл в `.gitignore`):

```properties
storePassword=REPLACE_ME
keyPassword=REPLACE_ME
keyAlias=crimeatrip
storeFile=/absolute/path/to/tourism-mobile-upload.jks
```

Никогда не коммить `key.properties`, `.jks`, пароли.
Подпись читает `android/app/build.gradle.kts` — без этого файла release
**не** падает обратно на debug key.

### 6.2. Вручную (если без скрипта)

```bash
cd tourism-mobile

flutter build apk --release \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io

adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Раздельные APK по ABI (меньше размер):

```bash
./scripts/build-signed-apk.sh --split-per-abi
# или:
flutter build apk --release --split-per-abi \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
```

### 6.3. App Bundle для Google Play (AAB)

```bash
./scripts/build-signed-apk.sh --aab
# или вручную:
flutter build appbundle --release \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
```

Артефакт: `build/app/outputs/bundle/release/app-release.aab`.

### 6.4. Debug APK без release-подписи (только для себя)

```bash
flutter build apk --debug \
  --dart-define=APP_ENV=local \
  --dart-define=DATA_SOURCE=mock
```

---

## 7. Шпаргалка «скопировал и запустил»

### iPhone + test API (release)

```bash
cd tourism-mobile
flutter build ios --release \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io \
&& xcrun devicectl device install app \
  --device 00008140-001A7D0C2668801C \
  build/ios/iphoneos/Runner.app \
&& xcrun devicectl device process launch \
  --device 00008140-001A7D0C2668801C \
  com.crimeatravel.tourismMobile
```

### Android signed APK + test API

```bash
cd tourism-mobile
./scripts/build-signed-apk.sh --install
```

### iPhone debug (правки UI без полной пересборки)

```bash
cd tourism-mobile
flutter run -d 00008140-001A7D0C2668801C \
  --dart-define=APP_ENV=test \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL=https://201-24-55-130.sslip.io
# затем r / R в терминале
```

---

## 8. Типичные ошибки

| Симптом | Причина / что сделать |
| --- | --- |
| `API_BASE_URL is required` | Для non-local не передан URL |
| `must use HTTPS` | Для test/staging/production нужен `https://` |
| Серый экран сразу при запуске release | Часто `APP_ENV=prod` без алиаса или опечатка в env: в debug это красный `Unsupported APP_ENV`, в release — пустой ErrorWidget. Нужен `production` или `prod` |
| `Mock data is allowed only in local` | `DATA_SOURCE=mock` с `APP_ENV=test` и т.п. |
| iOS install fail после `--no-codesign` | Нужна подпись Xcode / `flutter run` без `--no-codesign` |
| Android release без подписи | Нет `android/key.properties` или неверный `storeFile` |
| Device not found | Кабель, разблокировка, `flutter devices`, trust computer |

---

## 9. Связанные документы

- `tourism-mobile/README.md` — краткий старт
- `docs/flutter-app-architecture.md` — архитектура
- `docs/flutter-testing-guide.md` — тесты / goldens
- `docs/security/mobile-security.md` — mobile security baseline
- `docs/local-development.md` — local Compose + backend
