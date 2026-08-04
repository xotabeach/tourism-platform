# Figma MCP budget playbook (КрымТрип)

Цель: передать дизайн агенту **точно**, не сжигая Starter-лимит на обзорные
скриншоты и повторные `get_design_context`.

Файл: `5JLDCYifRsTI8Zex4jirbT` · страница `0:1` · инвентарь:
[`figma-screen-inventory-2026-08-03.json`](figma-screen-inventory-2026-08-03.json)

## Стоимость инструментов (примерно)

| Инструмент | Когда использовать | Стоимость |
| --- | --- | --- |
| `get_metadata` без `nodeId` | Список страниц | 1 (дёшево) |
| `get_metadata` page/`frame` | Дерево id/имя/bbox | 1, много пользы |
| `get_screenshot` | Только если нет PNG у агента | средне; `maxDimension` 512–1024 |
| `download_assets` | Иконки/SVG/фото из одного node | средне |
| `get_design_context` | Пиксели: fills, градиенты, текст, effects | **дорого**, 1 экран = 1 вызов |

**Не тратить MCP на:** общий скрин всей страницы, повторный metadata того же
node, `get_design_context` для простых list/settings при наличии PNG + inventory.

**Лучше бесплатно:** экспорт PNG из Figma Desktop (1x/2x) в
`tourism-platform/docs/design/screens-figma/` или `.tmp-ref-frames/`. Агент
читает файлы с диска без MCP.

## Процесс (3 фазы)

### Phase A — Inventory (сделано, 2 MCP)

1. `get_metadata` pages → `0:1`
2. `get_metadata` `0:1` → JSON inventory + имена экранов + nodeId
3. Product notes зафиксировать в handoff (ниже)

### Phase B — Visual pack (0 MCP предпочтительно)

Пользователь или агент с уже скачанными PNG кладёт референсы по приоритету.
Если PNG нет — один `get_screenshot` **на канонический экран**, не на всю
страницу (`maxDimension: 1024`).

### Phase C — Deep extract (MCP только для сложных)

`get_design_context` **только** для:

1. Баннер / paywall Travel+ (активна / неактивна / активация)
2. Подбор маршрута + результат (длинные, плотные UI)
3. Подбор маршрута (тревел +) — AI flow
4. Nav bar / иконки, если SVG не выгружены

Для простых экранов (уведомления, списки «Мои маршруты») — PNG + metadata bbox
достаточно; design_context — только если агент ломает отступы/типографику.

## Product notes для агента реализации

- Раздел **достопримечательности** остаётся в приложении.
- Из **nav bar** его убираем; 4-й таб (иконка карты) = **Мои маршруты**.
- Новые ключевые экраны (см. inventory `priorityNew`):
  - `Тревел + (активна)` — `280:4523`
  - `Активация подписки` — `347:1940`
  - `Настройки "Уведомления"` — `274:1278` / `347:2321`
  - `Подбор маршрута` — `351:2804`
  - `Результат подбора` — `351:3208`
  - `Мои маршруты` (история / избранное / подписки) — `351:3633`, `351:4056`, `351:4207`
  - `Подбор маршрута (тревел +)` — `357:5292` (полная), `357:5555` (короткая)
  - `Публикация маршрута` — `351:4579`

## Рекомендуемый бюджет следующей сессии (~8–12 вызовов)

| # | Вызов | Node | Зачем |
| --- | --- | --- | --- |
| 1–6 | `get_screenshot` 1024 **или** локальный PNG | priority screens | визуал для агента |
| 7 | `get_design_context` | `280:4523` Travel+ активна | баннер/статус |
| 8 | `get_design_context` | `347:1940` Активация | flow оформления |
| 9 | `get_design_context` | `351:2804` Подбор | главный новый flow |
| 10 | `get_design_context` | `351:3208` Результат | длинный экран |
| 11 | `get_design_context` | `357:5292` Подбор (тревел+) | AI variant |
| 12 | `download_assets` | nav / icons set | SVG иконок |

Остальное — из inventory + PNG без MCP.

## Что уже не повторять

- Metadata всей страницы уже в agent-tools dump + JSON inventory.
- Pixel-spec баннера неактивной подписки: `travel-plus-figma-live-extract.md`,
  `figma-spec-settings-support-v2.md`, `banner-flutter-diff-v3.md`.

## Status 2026-08-03

- Inventory: done
- Wireframes priority screens: done → `figma-wireframes-priority-2026-08-03.md`
- Next: PNG Desktop export for card-heavy screens OR `get_design_context` when quota allows (Результат подбора, Мои маршруты cards, Travel+ активна styles)
