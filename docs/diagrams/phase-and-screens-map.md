# Карта фаз и экранов (для дизайна)

Документ для синхронизации с дизайном экранов. Технические детали —
в [implementation-plan.md](implementation-plan.md) и [progress.md](progress.md).

**Статус на 2026-07-28:** завершены фазы 0–4; в активной разработке Phase 5 + 5.5/5.6.  
**Сейчас в работе по продукту:** polish Flutter UI/навигации, CI split, подготовка test backend.

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
  end

  subgraph near [Ближайшие_MVP]
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
| **3 Places** | Каталог мест, карточка места | **done** (в коде есть простой UI) |
| **4 Routes** | Каталог маршрутов, карточка маршрута со stops | **done** |
| 5 Shell | Welcome / Home / навбар / темы | in_progress |
| 6 Auth | Регистрация, вход, профиль | pending |
| 7 Favorites | Избранное мест и маршрутов | pending |
| 8A Builder | Форма подбора + результат маршрута | pending |
| 9 Execution | «Пройти маршрут», чеклист точек | pending |
| 8B / 12 / 13 | AI-чат, Travel+, Trip Planner | later |
| **14 Progress** | Звание, тп, достижения на профиле | pending |

---

## 2. Приоритет экранов для дизайна сейчас

Что имеет смысл рисовать **в первую очередь** (опираясь на уже реализованный shell и текущий scope):

```mermaid
flowchart TD
  subgraph now [Приоритет_1_текущий_polish]
    welcome[Welcome_AuthFlow]
    home[Home]
    placesCat[PlacesCatalog]
    placeDet[PlaceDetails]
    routesCat[RoutesCatalog]
    routeDet[RouteDetails]
    profile[Profile_MockData]
  end

  subgraph soon [Приоритет_2_после_Phase5]
    signIn[SignIn_SignUp]
    fav[Favorites]
    builder[RouteBuilderForm]
    builderRes[BuilderResult]
    active[ActiveRoute]
  end

  subgraph future [Приоритет_3_позже]
    chat[TravelPlus_Chat]
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
  home --> signIn
```

### Рекомендация другу-дизайнеру

1. **Сейчас:** до-polish уже реализованных Welcome/Auth/Home/Places/Routes/Profile flows + UX consistency (gestures/back/search/swipe deck).
2. **Следом:** Favorites, форма подбора маршрута + экран результата, затем real auth data wiring.
3. **Не блокировать MVP:** AI-чат, Trip Planner, публикация своих маршрутов — отдельные волны.

Шаблон Welcome у вас уже есть в Figma — его не ломаем; новые экраны лучше на отдельной странице (как «Cursor — экраны v1»).

---

## 3. Главный пользовательский путь (MVP)

```mermaid
journey
  title MVP traveler journey
  section Старт
    Открыть Welcome: 5: Traveler
    Войти или пропустить: 4: Traveler
  section Каталог
    Главная с категориями: 5: Traveler
    Листать места Крыма: 5: Traveler
    Открыть карточку места: 5: Traveler
    Листать готовые маршруты: 4: Traveler
    Открыть карточку маршрута: 5: Traveler
  section Действие
    Сохранить в избранное: 3: Traveler
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
  end

  subgraph phases [Фазы]
    Ph3[Phase3_done]
    Ph4[Phase4_done]
    Ph5[Phase5_in_progress]
    Ph6_7[Phase6_7]
    Ph8_9[Phase8A_9]
  end

  S_places --> Ph3
  S_routes --> Ph4
  S_welcome --> Ph5
  S_home --> Ph5
  S_auth --> Ph6_7
  S_fav --> Ph6_7
  S_builder --> Ph8_9
  S_run --> Ph8_9
```

---

## 5. Типы маршрутов (важно для UI)

```mermaid
flowchart LR
  editorial[Editorial_готовые]
  generated[Generated_подбор]
  user[UserCreated_свои]

  editorial -->|public_каталог| catalog[RoutesCatalog]
  generated -->|private_после_формы| my[Мои_или_результат]
  user -->|позже_Phase11| my
```

В MVP в публичном каталоге — **редакционные** маршруты. Сгенерированный — личный результат builder. Свои маршруты пользователя — позже.

---

## 6. Как смотреть диаграммы

- В GitLab / GitHub Markdown mermaid рендерится в preview.
- В VS Code / Cursor — preview Markdown.
- Чтобы перенести в FigJam: скопировать блок mermaid или сказать агенту «положи это на FigJam board».

Живой статус фаз всегда в [progress.md](progress.md).
