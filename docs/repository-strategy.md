# Стратегия репозиториев

## Управляющий репозиторий

`tourism-platform` является управляющим repository и точкой входа для
документации, локальной разработки и orchestration. Он подключается вместе с
остальными repositories как submodule общего Git superproject. Прикладной код
не смешивается в одном Git history.

Планируемая структура:

```text
mobile_travel_app/
├── .gitmodules
├── README.md
├── tourism-platform/
│   ├── docs/
│   ├── scripts/
│   └── compose.yaml
├── tourism-mobile/
├── tourism-backend/
├── tourism-infrastructure/
└── tourism-documentation/
```

`mobile_travel_app` — Git superproject. Каждый дочерний каталог является
самостоятельным repository и зарегистрированным submodule:

- `tourism-platform` — управление workspace;
- `tourism-mobile` — Flutter mobile application;
- `tourism-backend` — modular monolith и API;
- `tourism-infrastructure` — Kubernetes, Helm и environments;
- `tourism-documentation` — расширенная документация.

Remote repositories размещаются в private GitLab group
`crimea-travel-platform`. `scripts/clone-repositories.sh` или его PowerShell-аналог
предварительно проверит доступность projects и добавит их в superproject.
Существующие каталоги скрипт не перезаписывает.

Local Compose остаётся в `tourism-platform`, поскольку обеспечивает общий
developer workspace. Production deployment assets принадлежат только
`tourism-infrastructure`.

## Правила зависимостей

- Mobile зависит от опубликованного API contract, а не от backend source.
- Backend не зависит от mobile repository.
- Infrastructure получает versioned artifacts и configuration contracts, но
  не копирует application source.
- Совместимость фиксируется submodule pointers, API contracts и release
  metadata.
- Изменение API сначала описывается контрактом, затем реализуется и только
  после этого потребляется mobile.

## Рабочий процесс

1. Разработка и review выполняются в соответствующем дочернем repository.
2. Каждый repository независимо проходит CI и выпускает versioned artifacts.
3. После merge superproject обновляет submodule pointer.
4. Интеграционная проверка использует зафиксированные commits, contracts и
   images.
5. Несовместимые изменения не выпускаются до готовности потребителей.

## Что не следует хранить в управляющем репозитории

- application code mobile или backend;
- production secrets и локальные `.env`;
- vendor binaries и пользовательские данные;
- копии содержимого submodules;
- legacy code или resources без лицензии.
