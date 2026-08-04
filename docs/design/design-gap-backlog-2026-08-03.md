# Design gap backlog — КрымТрип (2026-08-03)

Источник: PNG `/Users/nikita/Downloads/КрымТрип-2` →
[`screens-figma/krymtrip-2/`](screens-figma/krymtrip-2/), inventory
[`figma-screen-inventory-2026-08-03.json`](figma-screen-inventory-2026-08-03.json),
wireframes [`figma-wireframes-priority-2026-08-03.md`](figma-wireframes-priority-2026-08-03.md).

**MCP:** не тратить на общий скрин всей страницы. PNG уже выгружены —
достаточно для верстки. `get_design_context` только для сложных баннеров /
плотных форм, если пиксели «ломаются». См.
[`figma-mcp-budget-playbook.md`](figma-mcp-budget-playbook.md).

## Product decisions (зафиксировано)

1. **Достопримечательности** остаются в приложении, но **убираются из nav bar**.
2. 4-й таб (иконка карты) = **Мои маршруты**.
3. 3-й пункт (**+**) не ведёт на вкладку: анимация → две кнопки
   **Опубликовать** | **Подобрать** → соответствующие экраны.
4. Подбор маршрута (параметры + ИИ / Travel+) — новый ключевой flow.

## Gap matrix

| Экран / элемент | Дизайн | В приложении сейчас | Статус |
| --- | --- | --- | --- |
| Nav bar базовый | `00-nav-bar` | есть | polish |
| Nav + compose (Опубликовать / Подобрать) | `00-nav-plus-compose` | mock UI | **в WIP** |
| Мои маршруты (избранное / подписки / история) | `10-*` | 4-й таб | **в WIP** |
| Подбор маршрута (по параметрам) | `20-route-match` | форма + mock | **в WIP** |
| Подбор (тревел+) параметры | `21-*` | нет | после базового подбора |
| Подбор с ИИ (чат) | `22-route-match-ai-chat` | нет | Phase 8B / mock UI |
| Результат подбора | `23-route-match-results` | stub | **в WIP** |
| Публикация маршрута | `24-route-publish` | stub | **в WIP** |
| Тревел+ активна | `30-travel-plus-active` | UI mock | **готово (мок)** |
| Тревел+ неактивна | `30-travel-plus-inactive` | AI-benefit + CTA → checkout | **готово (мок)** |
| Активация подписки | `31-subscription-checkout` | checkout UI mock | **готово (мок)** |
| Настройки: баннер подписки активна/нет | `32-*` | есть баннер | сверить |
| Уведомления: настройки toggles | `40-*` | есть + entry в inbox | ок |
| Уведомления: inbox (новые / прочитанные) | `41-notifications-inbox` | mock inbox | **готово (мок)** |
| Достопримечательности catalog/detail | — | есть | оставить, убрать из tab |
| Главная / слайдер / карточка маршрута / профиль | — | есть | polish по мере |
| Auth / welcome / support / report | — | есть | мелкий polish |
| Places из home filter | — | `goNamed(places)` | перевести на push вне tab |

## Порядок реализации (эта сессия → дальше)

### P0 — навигация и каркас новых разделов

1. Compose-меню над nav bar (`Опубликовать` / `Подобрать`).
2. 4-й таб → **Мои маршруты**; places — вне tab (push / deep link).
3. Экран **Мои маршруты** (tabs + карточки на favorites / mock).
4. Экран **Подбор маршрута** (форма по параметрам, CTA).
5. Stub **Результат подбора** + stub **Публикация**.

### P1 — Travel+ и уведомления

6. Контент **Тревел+ (активна)** по макету.
7. Экран **Активация подписки** (checkout UI, оплата — mock).
8. Inbox уведомлений + entry из settings.

### P2 — AI / backend later

9. Ветка «Подбор с ИИ» (чат UI mock → Ollama later).
10. Реальный Route Builder / publish API (Phase 8A / 11).

## Ref frames для команды

Каталог: `tourism-platform/docs/design/screens-figma/krymtrip-2/`
(ASCII-имена, см. mapping в этом PR / commit).
