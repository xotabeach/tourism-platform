# Профиль репозитория tourism-mobile

## Назначение

Flutter-клиент Android/iOS (CrimeaTrip). Private GitLab repo, submodule
workspace. Стек: [stack.md](../stack.md).

## Ответственность

- Пользовательские сценарии: каталог, маршруты, профиль, публикация, inbox.
- Сетевой клиент и ошибки API.
- Secure storage токенов (Keychain/Keystore).
- Ограниченный offline — позже; сейчас не SoT.

## Вне целей

- Доменная логика как источник истины.
- Прямой доступ к PostgreSQL / Redis / Ollama.
- Импорт ORM backend.
- Облачная infra.
- Официальное госприложение.

## Стек

- Flutter/Dart, feature-first, Riverpod, GoRouter, Dio.
- `flutter_secure_storage` только для credentials.
- Карты — адаптер (сейчас preview, не полноценный routing UI).
- Env через `--dart-define`; secrets не в bundle.
- Lean CI: локально `./scripts/validate.sh`; APK job manual.

Freezed/`json_serializable` — опционально Phase 5, не блокер as-built.
Drift/Isar — после offline spike.

## Интеграции

- OpenAPI `tourism-backend`.
- FCM (Android); iOS APNs — ещё credentials.
- Не ходит в Gemma/Gemini.

## Поэтапный план

### Этап 1. Проектирование

- [x] Feature-first, GoRouter, Riverpod, shell, tokens, secure storage.
- [ ] Сверка части SVG/token с Figma Dev Mode.
- [ ] Offline storage spike (Drift vs Isar).

### Этап 2. Минимальный продукт

- [x] OTP session, профиль (тп/звания/достижения API).
- [x] Поиск (fullscreen + история сессии), карточка места, каталог маршрутов, избранное.
- [x] Публикация user route + отзывы.
- [x] Единое отображение экспертного статуса в общих карточках пользователя
  и маршрута (`author_is_expert`, градиентная рамка и бейдж).
- [ ] Route builder / execution (Phase 8A/9).
- [ ] Offline download.

### Этап 3. Надёжность

- [x] Typed network failures, retry UI.
- [ ] Полный refresh concurrency + a11y/l10n.
- [ ] Crash reporting без токенов.

### Этап 4. Workspace

- [x] Private remote, submodule, lean/full CI files.
- [ ] Зафиксировать semver контракта с backend для первого staging.
