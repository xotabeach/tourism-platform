# ADR-007: Authentication and session strategy

- Статус: **принято** (направление; реализация — Phase 6)
- Дата: 2026-07-23

## Контекст

Нужна аутентификация для Flutter (Android/iOS) с последующей web/admin
панелью. Требования: revoke, multi-device, logout, password change invalidation,
защита от кражи refresh, масштабирование, auditability. Redis уже в local
stack. Auth код пока отсутствует (`identity` / `users` — stubs).

## Решение

**Гибрид (вариант 4):**

1. **Native mobile:** short-lived JWT **access** token (Bearer) + **opaque**
   refresh token (rotation + family/reuse detection). Refresh digest в
   PostgreSQL; опциональный Redis для rate-limit / hot revoke cache.
2. **Future web/admin:** secure **HttpOnly** session cookies (+ CSRF), не
   хранить long-lived JWT в `localStorage`.
3. Общий account/session model в `identity`; разные transport bindings.

Пароли: Argon2id. Детали: [authentication-and-token-security.md](../security/authentication-and-token-security.md).

## Сравнение альтернатив

### 1) Short-lived JWT access + opaque refresh

| Тема | Оценка |
| --- | --- |
| Threat model | Access кража ограничена TTL; refresh — главный секрет |
| Revocation | Access: TTL / optional denylist; refresh: DB revoke |
| Rotation | Refresh rotation + reuse → revoke family |
| Logout | Delete refresh family; access доживает TTL |
| Multi-device | Одна family/device record на устройство |
| Token theft | Secure storage + rotation; reuse detection |
| Scaling | Access stateless verify; refresh stateful |
| Redis | Optional (limits, denylist), не единственный SoT sessions |
| Mobile storage | Refresh in Keychain/Keystore; access in memory |
| CSRF | N/A for Bearer |
| XSS | JSON API; XSS risk on future web renderers |
| Auditability | session/device rows + security events |
| Ops | Key management for JWT signing; migration of digests |

**Плюсы:** хорошо для native; привычный mobile pattern.  
**Минусы:** access не мгновенно revoke без denylist.

### 2) Fully opaque server-side sessions

| Тема | Оценка |
| --- | --- |
| Revocation | Мгновенная |
| Scaling | Каждый запрос → session store |
| Redis dependency | Часто сильная (или Postgres на каждый request) |
| Mobile storage | Opaque session id в secure storage |
| CSRF | Bearer header OK if not cookies |
| Ops | Проще крипто (нет JWT), выше load на store |

Отклонено как **единственный** mobile механизм: выше latency/dependency на
каждый API call; JWT access даёт лучший trade-off при коротком TTL.

### 3) Cookie session only (web-style)

| Тема | Оценка |
| --- | --- |
| Mobile | Cookie jars неудобны/нестандартны для Flutter API clients |
| CSRF | Обязателен |
| XSS | HttpOnly помогает против JS theft |

Подходит для **web/admin**, не как primary native transport.

### 4) Hybrid (выбран)

Bearer для native; cookies для web/admin; общий session/refresh backend.
CSRF только на cookie surfaces. XSS mitigated by HttpOnly cookies + CSP на
web. Operational complexity выше, но соответствует реальному roadmap.

## Последствия

- Phase 6 реализует mobile Bearer path first.
- Web/admin cookie path — отдельная задача при появлении admin UI.
- Signing keys вне Git; algorithm allowlist; минимальные JWT claims.
- Redis не хранит plaintext refresh tokens.
- Тесты: rotation, reuse, logout, password-change revoke, enumeration.
