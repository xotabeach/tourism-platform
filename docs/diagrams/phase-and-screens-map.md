# Карта фаз и экранов (для дизайна)

Документ для синхронизации с дизайном экранов. Технические детали —
в [implementation-plan.md](implementation-plan.md) и [progress.md](progress.md).

**Статус на 2026-08-01:** фазы 0–4 и **6.5 ops admin** — done; Phase 5 / 5.5–5.6 /
6 / 7 — in_progress (реальный OTP+JWT на test contour, favorites, shell polish).  
**Сейчас по продукту:** polish shell/nav и профиля; ops-админка на test; next —
Phase 8A Route Builder.

---

## 1. Roadmap фаз (что уже есть / что дальше)

```mermaid
flowchart LR
  subgraph done [Сделано]
    p0[Phase0_Docs]
    p1[Phase1_Infra]
    p2[Phase2_API]
    p3[Phase3_Places]
    p4[Phase4_EditorialRoutes]
    p65[Phase6_5_OpsAdmin]
  end

  subgraph near [В_работе_и_MVP]
    p5[Phase5_AppShell]
    p6[Phase6_Auth]
    p7[Phase7_Favorites]
    p8a[Phase8A_RouteBuilder]
    p9[Phase9_Execution]
  end

  subgraph later [Позже]
    p8b[Phase8B_AI]
    p10[Phase10_Staging]
    p11[Phase11_UserRoutes]
    p12[Phase12_TravelPlus]
    p13[Phase13_TripPlanner]
    p14[Phase14_ProgressAchievements]
  end

  p0 --> p1 --> p2 --> p3 --> p4 --> p5
  p5 --> p6 --> p7
  p6 --> p65
  p3 --> p8a
  p6 --> p8a --> p9
  p9 --> p14
  p8a --> p8b
  p9 --> p10 --> p11
  p8a --> p12 --> p13
```

| Фаза | Для дизайна значит | Статус |
| --- | --- | --- |
| 0–2 | Инфра, не экраны | done |
| **3 Places** | Каталог мест, карточка места | **done** |
| **4 Routes** | Каталог маршрутов, карточка маршрута со stops | **done** |
| 5 Shell | Welcome / Home / навбар / темы | in_progress |
| 6 Auth | Регистрация, вход, профиль (API OTP/JWT на test) | in_progress |
| **6.5 Ops** | Внутренняя админка `/admin` (не mobile UI) | **done** |
| 7 Favorites | Избранное мест и маршрутов; guest profile | in_progress |
| 8A Builder | Форма подбора + результат маршрута | pending |
| 9 Execution | «Пройти маршрут», чеклист точек | pending |
| 8B / 12 / 13 | AI-чат, Travel+, Trip Planner | later |
| **14 Progress** | Звание, тп, достижения на профиле | pending |

---

## 2. Приоритет экранов для дизайна сейчас

```mermaid
flowchart TD
  subgraph now [Приоритет_1_текущий_polish]
    welcome[Welcome_AuthFlow]
    home[Home_StickyBrand]
    placesCat[PlacesCatalog]
    placeDet[PlaceDetails]
    routesCat[RoutesSwipeDeck]
    routeDet[RouteDetails]
    profile[Profile_Self_And_Guest]
    settings[Settings_Support_TravelPlus]
  end

  subgraph ops [Ops_не_mobile]
    adminUsers[Admin_Users_OTP]
    adminChat[Admin_SupportChat]
  end

  subgraph soon [Приоритет_2_следующее]
    fav[FavoritesScreen]
    active[ActiveRoute]
  end

  subgraph shipped [Реализовано_2026_08_26]
    builder[RouteBuilderForm]
    builderRes[BuilderResult]
    chat[TravelPlus_Chat]
    chatHist[ChatHistory]
    allList[AllList_Paginated]
  end

  subgraph future [Приоритет_3_позже]
    myRoutes[MyUserRoutes]
    trip[TripPlanner]
  end

  welcome --> home
  home --> placesCat --> placeDet
  home --> routesCat --> routeDet
  home --> builder --> builderRes
  routeDet --> active
  home --> fav
  home --> profile
  profile --> settings
  adminUsers -.-> adminChat
```

### Shell / nav (mobile) — актуальные правила

```mermaid
flowchart LR
  subgraph expanded [Полный_navbar]
    h[Home]
    r[Routes]
    b[Builder]
    m[Map]
    p[Profile]
  end

  subgraph detail [Detail_chrome]
    drop[Active_droplet]
    cta[CTA_Пройти_или_TravelPlus]
  end

  subgraph guest [Чужой_профиль]
    back[Home_slot_стрелка_назад]
    rest[Остальные_вкладки_как_обычно]
  end

  expanded -->|collapse_lerp| detail
  detail -->|expand_из_капли| expanded
  expanded -->|guest_profile| guest
```

- Detail/settings: liquid collapse (lerp капли + `translationX` иконок) →
  компактная капля + опциональный CTA.
- Чужой профиль: **не** схлопывать бар; слот Home = history-back (`pop`).
- Scroll вниз на вкладке: иконка активной вкладки → «наверх».

### Рекомендация другу-дизайнеру

1. **Сейчас:** polish Home/Routes/Profile/Settings + consistency жестов.
2. **Следом:** история в «Мои маршруты»; реальный результат подбора (8A);
   Active Route (9); achievements API.
3. **Уже as-built (не блочить):** публикация своих маршрутов + admin
   moderation; тп/звания/leaderboard; inbox.
4. Ops UI живёт только в `/admin` (SQLAdmin) — отдельные макеты mobile не нужны.

---

## 3. Главный пользовательский путь (MVP)

```mermaid
journey
  title MVP traveler journey
  section Старт
    Открыть Welcome: 5: Traveler
    Войти по OTP: 5: Traveler
  section Каталог
    Главная с категориями: 5: Traveler
    Листать места Крыма: 5: Traveler
    Открыть карточку места: 5: Traveler
    Листать готовые маршруты: 4: Traveler
    Открыть карточку маршрута: 5: Traveler
  section Социальное
    Открыть чужой профиль: 4: Traveler
    Лайк профиля / избранное маршрута: 3: Traveler
  section Действие
    Собрать свой маршрут: 4: Traveler
    Пройти по точкам: 5: Traveler
```

---

## 4. Связь экранов и фаз разработки

```mermaid
flowchart TB
  subgraph screens [Экраны]
    S_welcome[Welcome]
    S_home[Home]
    S_places[Places]
    S_routes[Routes]
    S_auth[Auth_Profile]
    S_fav[Favorites]
    S_builder[Builder]
    S_run[ActiveRoute]
    S_ops[OpsAdmin_Web]
  end

  subgraph phases [Фазы]
    Ph3[Phase3_done]
    Ph4[Phase4_done]
    Ph5[Phase5_in_progress]
    Ph6_7[Phase6_7_favorites_done]
    Ph65[Phase6_5_done]
    Ph11[Phase11_publish_as_built]
    Ph8_9[Phase8A_9_pending]
  end

  S_places --> Ph3
  S_routes --> Ph4
  S_welcome --> Ph5
  S_home --> Ph5
  S_auth --> Ph6_7
  S_fav --> Ph6_7
  S_ops --> Ph65
  S_builder --> Ph8_9
  S_run --> Ph8_9
```

*(Публикация user routes / модерация — as-built Phase 11 slice; на схеме
отдельно не вынесена — живёт в Routes + Profile + `/admin`.)*

---

## 5. Типы маршрутов (важно для UI)

```mermaid
flowchart LR
  editorial[Editorial_готовые]
  generated[Generated_подбор]
  user[UserCreated_свои]

  editorial -->|public_каталог| catalog[RoutesCatalog]
  user -->|public_после_approve| catalog
  generated -->|private_после_формы| result[Match_или_результат]
  user -->|drafts_mine_profile| profile[Profile_мои]
```

В каталоге — редакционные + **published** `user_created`. Сгенерированный —
личный результат builder (**Phase 8A**, пока UI режет каталог). Свои draft /
pending / published — на профиле через `/routes/mine`; таб «Мои маршруты» =
избранное / follows / history placeholder.

---

## 6. Как смотреть диаграммы

- В GitLab / GitHub Markdown mermaid рендерится в preview.
- В VS Code / Cursor — preview Markdown.
- Чтобы перенести в FigJam: скопировать блок mermaid или сказать агенту «положи это на FigJam board».

Живой статус фаз всегда в [progress.md](progress.md).
