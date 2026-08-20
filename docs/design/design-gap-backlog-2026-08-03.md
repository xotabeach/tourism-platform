# Design gap backlog — КрымТрип (2026-08-03)

Источник: PNG `/Users/nikita/Downloads/КрымТрип-2` →
[`screens-figma/krymtrip-2/`](screens-figma/krymtrip-2/), inventory
[`figma-screen-inventory-2026-08-03.json`](figma-screen-inventory-2026-08-03.json),
wireframes [`figma-wireframes-priority-2026-08-03.md`](figma-wireframes-priority-2026-08-03.md).

**MCP:** не тратить на общий скрин всей страницы. PNG уже выгружены —
достаточно для верстки. `get_design_context` только для сложных баннеров /
плотных форм, если пиксели «ломаются». См.
[`figma-mcp-budget-playbook.md`](figma-mcp-budget-playbook.md).

**As-built sync:** 2026-08-06 — статусы ниже сверены с кодом (не только с
Figma). Живой статус фаз: [progress.md](../progress.md).

## Product decisions (зафиксировано)

1. **Достопримечательности** остаются в приложении, но **убираются из nav bar**.
2. 4-й таб (иконка карты) = **Мои маршруты**.
3. 3-й пункт (**+**) не ведёт на вкладку: анимация → две кнопки
   **Опубликовать** | **Подобрать** → соответствующие экраны.
4. Подбор маршрута (параметры + ИИ / Travel+) — новый ключевой flow;
   серверная генерация — Phase 8A/8B (пока UI + срез каталога).

## Gap matrix

| Экран / элемент | Дизайн | В приложении сейчас | Статус |
| --- | --- | --- | --- |
| Nav bar базовый | `00-nav-bar` | есть | polish |
| Nav + compose (Опубликовать / Подобрать) | `00-nav-plus-compose` | есть | ok |
| Моё избранное (маршруты / места / подписки / история) | `10-*` | favorites + follows API, двухступенчатый remove; история = placeholder | **partial** |
| Подбор маршрута (по параметрам) | `20-route-match` | форма UI; без Route Builder API | **UI only** |
| Подбор (тревел+) параметры | `21-*` | нет | после базового подбора / Phase 12 |
| Подбор с ИИ (чат) | `22-route-match-ai-chat` | canned local replies | Phase 8B / mock UI |
| Результат подбора | `23-route-match-results` | срез публичного каталога | **UI only** (до 8A) |
| Публикация маршрута | `24-route-publish` | draft/media/submit + admin moderation | **готово** |
| Тревел+ активна | `30-travel-plus-active` | UI mock | **готово (мок)** |
| Тревел+ неактивна | `30-travel-plus-inactive` | AI-benefit + CTA → checkout | **готово (мок)** |
| Активация подписки | `31-subscription-checkout` | checkout UI mock | **готово (мок)** |
| Настройки: баннер подписки активна/нет | `32-*` | есть баннер | сверить |
| Уведомления: настройки toggles | `40-*` | есть + OS permission sync | ok |
| Уведомления: inbox (новые / прочитанные) | `41-notifications-inbox` | API inbox + badge/toast | **готово** |
| Достопримечательности catalog/detail | — | есть | оставить, вне tab |
| Главная / слайдер / карточка маршрута / профиль | — | есть; ранги/тп/топ API | polish; achievements mock |
| Auth / welcome / support / report | — | есть | мелкий polish |
| Places из home filter | — | push вне tab | ok |

## Порядок реализации (исторический → актуально)

### P0 — навигация и каркас (сделано / почти)

1. Compose-меню над nav bar (`Опубликовать` / `Подобрать`) — **done**.
2. 4-й таб → **Мои маршруты**; places вне tab — **done**.
3. Экран **Мои маршруты** — favorites + subscriptions **done**; history —
   remaining.
4. Экран **Подбор маршрута** (форма) — **UI done**; backend Phase 8A.
5. **Публикация** — **done** (API + mobile + admin). Результат подбора —
   facade до 8A.

### P1 — Travel+ и уведомления

6. Контент **Тревел+** / checkout — **UI mock**; entitlements Phase 12.
7. Inbox уведомлений — **done** (API); FCM tray — Android as-built, iOS APNs
   open.

### P2 — AI / backend later

9. Ветка «Подбор с ИИ» (чат UI mock → Ollama later).
10. Реальный Route Builder (Phase 8A) + execution (Phase 9).
11. Achievements API (остаток Phase 14); owner drafts list in «Мои маршруты».

## Ref frames для команды

Каталог: `tourism-platform/docs/design/screens-figma/krymtrip-2/`
(ASCII-имена, см. mapping в этом PR / commit).
