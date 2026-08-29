# ADR-011 — Персональные рекомендации маршрутов без filter bubble

- **Статус:** accepted; backend v1 implemented 2026-08-29, mobile R2 pending
- **Дата:** 2026-08-28
- **Владельцы:** product + backend + mobile
- **Связанные документы:** [route-swipe-recommendations.md](../route-swipe-recommendations.md),
  [route-intelligence-roadmap.md](../route-intelligence-roadmap.md), Phase R8,
  Phase 14

## Контекст

В мобильном приложении уже есть конечная свайп-колода маршрутов и экран
настроек предпочтений. Backend хранит:

- `preferred_categories`;
- `preferred_difficulty`;
- `travels_with_kids`;
- `travels_with_pets`.

Пока колода использует общий каталог, а preferences не участвуют в выдаче.
Нельзя строить персонализацию по наивному правилу «пользователь открыл два
маршрута с горами — показываем только горы»: это ухудшает discovery,
создаёт ложный профиль и делает рекомендации непредсказуемыми.

## Решение

Рекомендательная система v1 — объяснимый batch/синхронный hybrid ranker без
ML и embeddings. Она разделяет:

1. **hard constraints** — то, что нельзя нарушать;
2. **explicit profile** — то, что пользователь сообщил сам;
3. **positive behaviour** — favorite, accept, start, completion;
4. **weak behaviour** — просмотр/длительность карточки;
5. **negative behaviour** — skip с конечным cooldown;
6. **context** — сезон, время, регион, погодные и availability signals;
7. **diversity/exploration** — обязательная защита от однообразия.

## Semantics of signals

| Сигнал | Сила | Срок | Правило |
| --- | --- | --- | --- |
| `travels_with_kids/pets` | hard или strong soft | пока профиль не изменён | исключать только явно несовместимые маршруты; unknown не считать «нет» |
| `preferred_difficulty` | soft по умолчанию | профиль | показывать близкие уровни; strict mode — отдельное действие пользователя |
| `preferred_categories` | strong | профиль | prior, но не единственная категория |
| favorite | strong positive | decayed | нормализовать по категориям и регионам |
| start/completion | strongest positive | decayed | completion сильнее открытия |
| meaningful view | weak positive | 7–14 дней | считать только после dwell/scroll threshold; cap contribution |
| skip | negative | 14 дней по умолчанию | не «никогда»; причина — будущая опция |
| current location | contextual | session/opt-in | coarse region; exact GPS только в navigation opt-in |

Просмотр не записывается как preference update и не меняет ответы quiz.

## Ranking contract v1

Кандидаты сначала проходят publication/quality/availability gates. Для каждого
оставшегося маршрута вычисляются нормализованные признаки 0..1:

```text
score =
    0.30 * explicit_profile_match
  + 0.20 * content_affinity
  + 0.10 * context_fit
  + 0.10 * popularity
  + 0.10 * freshness
  + 0.10 * completion_likelihood
  + 0.10 * exploration_bonus
```

Весовые коэффициенты — версия конфигурации, а не скрытая магия. Их можно
изменить только через review и записать в `ranker_version`.

`behavioural_bonus` не является отдельной безграничной суммой: его вклад
ограничен cap 0.25 итогового score и экспоненциально затухает. Один просмотр
никогда не может превратить категорию в hard filter.

## Diversity policy

После ranking применяется constrained reranking:

- candidate pool не менее 50 (если каталог позволяет);
- максимум 40% карточек одной категории;
- максимум 50% одного региона;
- не менее 20% exploration, если есть подходящие unseen routes;
- не показывать один и тот же маршрут повторно в активной колоде;
- минимум один маршрут с альтернативным типом опыта при достаточном
  каталоге;
- если hard constraints оставляют только одну категорию, честно показать
  empty/diversity warning, а не выдумывать разнообразие.

Размер deck, caps и cooldown — remote/config values с безопасными границами;
изменение требует метрик и rollback.

## Cold start

- preferences заполнены → использовать их как prior;
- preferences пусты → popularity/freshness + regional/category diversity;
- после первого favorite не перестраивать всю колоду в одну тему;
- пользователю дать «Сбросить персонализацию» и «Почему этот маршрут?».

## Data model

`route_recommendation_feedback` хранит append-only события с типом действия,
временем, источником и опциональным контекстом без PII. Минимальный набор:

```text
user_id, route_id, action
  (impression | meaningful_view | favorite | start | complete | skip | hide_category)
created_at, deck_date, ranker_version, request_id
```

`route_recommendation_deck_items` хранит состав и score дневной колоды. Новая
генерация идемпотентна по `(user_id, deck_date, route_id, ranker_version)`.
Сырые тексты и exact GPS в recommendation events не сохраняются.

## User controls and trust

- копирайт объясняет причину рекомендации без обещания абсолютной точности;
- отдельные controls «меньше такого», «не сейчас», «сбросить»;
- изменение preferences обновляет будущую колоду, но не ломает текущий экран;
- пользователь может отключить персонализацию и получить editorial/popular
  deck;
- события и retention описаны в privacy docs.

## Evaluation

До запуска собираем offline fixture set и сравниваем версии по:

- catalog coverage;
- category/region diversity;
- novelty и repeat rate;
- explicit preference match;
- skip/favorite/start/completion rates;
- empty/rejection rate;
- latency и quota cost.

Guardrails: не ухудшать coverage ниже согласованного порога, не повышать
однообразие, не использовать sensitive attributes для скрытого исключения и
не отправлять PII в AI/vendor providers.

## Rollout

1. shadow ranker без изменения UI;
2. внутренний test cohort;
3. 5–10% authenticated users с feature flag;
4. расширение при выполнении guardrails;
5. rollback к editorial/popular deck одной настройкой.

## Acceptance

- preferences влияют на score и видны в explainability fixture;
- два просмотра одной категории не создают hard filter;
- skip имеет cooldown и идемпотентен;
- category/region caps и exploration проверены property tests;
- empty/error/offline states определены;
- отключение personalization работает и удаляет/анонимизирует допустимые
  behavioural signals согласно retention policy;
- ranker version, metrics и rollback documented.
