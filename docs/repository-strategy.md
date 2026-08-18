# Стратегия репозиториев

## Управляющий репозиторий

Фактическая модель группы GitLab `travel-platform2` — **четыре** repository:

```text
workspace/                         # Git superproject
├── .gitmodules
├── README.md
├── Makefile
├── docs/                          # индекс-ссылки на канонические docs
├── tourism-platform/              # docs, Compose, будущие Helm/K8s
├── tourism-backend/               # FastAPI modular monolith
└── tourism-mobile/                # Flutter app
```

| Repository | Назначение |
| --- | --- |
| `workspace` | Точка входа, submodule pointers, scripts migrate/mirror |
| `tourism-platform` | Документация, ADR, local Compose, staging/prod infra assets |
| `tourism-backend` | API, бизнес-логика, PostgreSQL/PostGIS, Redis |
| `tourism-mobile` | Flutter Android/iOS |

Дополнительные repositories (`tourism-infrastructure`, `tourism-documentation`)
**не создаются**. Kubernetes/Helm и расширенная документация живут в
`tourism-platform`.

Remote: private GitLab group
[`travel-platform2`](https://gitlab.com/travel-platform2). Group создаётся в UI;
`scripts/setup-gitlab-group.sh` переносит projects. Primary CI — GitLab CI.

Local Compose остаётся в `tourism-platform`. Test-deploy manifests
(`deploy/test`, as-built) тоже здесь. Целевой GPU-стек Gemma 4 —
[stack.md](stack.md), не test host.

## Правила зависимостей

- Mobile зависит от опубликованного API contract, а не от backend source.
- Backend не зависит от mobile repository.
- Platform получает versioned artifacts и configuration contracts, но не
  копирует application source.
- Совместимость фиксируется submodule pointers, API contracts и release
  metadata.
- Изменение API сначала описывается контрактом, затем реализуется и только
  после этого потребляется mobile.

## Рабочий процесс

1. Разработка и review выполняются в соответствующем дочернем repository.
2. Каждый repository независимо проходит GitLab CI.
3. После merge superproject обновляет submodule pointer.
4. Интеграционная проверка использует зафиксированные commits и contracts.
5. Несовместимые изменения не выпускаются до готовности потребителей.

Подробности: [development-conventions.md](development-conventions.md).

## Что не следует хранить в platform / workspace

- application code mobile или backend;
- production secrets и локальные `.env`;
- vendor binaries и пользовательские данные;
- копии содержимого submodules;
- legacy code или resources без лицензии.
