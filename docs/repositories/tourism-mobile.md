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
- Прямой доступ к PostgreSQL / Redis / LM Studio.
- Импорт ORM backend.
- Облачная infra.
- Официальное госприложение.

## Стек

- Flutter/Dart, feature-first, Riverpod, GoRouter, Dio.
- `flutter_secure_storage` только для credentials.
- Карты — адаптер (сейчас preview, не полноценный routing UI).
- Env через `--dart-define`; secrets не в bundle.
- Локально `./scripts/validate.sh`; APK job остаётся manual в mobile CI.

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
- [x] Поиск (fullscreen + история сессии), карточка места с галереей, картой,
  связанными маршрутами и отдельными отзывами; каталог маршрутов, избранное.
- [x] Публикация user route + отзывы маршрутов/локаций с фото и ответами.
- [x] Топ путешественников по макету: текущая позиция, podium top-3, тп и
  публичные профили.
- [x] «Моё избранное»: маршруты/места/подписки, поздний auto-remove threshold,
  фиксированное swipe-состояние с кнопкой «Убрать» и undo; единый контур
  активного/неактивного сердца.
- [x] Единое отображение экспертного статуса в общих карточках пользователя
  и маршрута (`author_is_expert`, градиентная рамка и бейдж).
- [x] Route builder: форма + AI-чат + proposal→accept (2026-08-26)
- [ ] Route execution (Phase 9).
- [ ] Offline download.

### Этап 3. Надёжность

- [x] Typed network failures, retry UI.
- [ ] Полный refresh concurrency + a11y/l10n.
- [ ] Crash reporting без токенов.

### Этап 4. Workspace

- [x] Private remote, submodule, local validation and manual APK CI.
- [ ] Зафиксировать semver контракта с backend для первого staging.
