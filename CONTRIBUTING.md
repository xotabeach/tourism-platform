# Участие в разработке

## Общие правила

- Обсуждайте существенные изменения в issue до реализации.
- Не переносите код и ресурсы из legacy Android-проекта.
- Не добавляйте секреты, токены, production-конфигурацию или персональные данные.
- Сохраняйте доменные границы и не импортируйте ORM-модели между модулями.
- Пишите документацию на русском языке, сохраняя technical names на английском.

## Ветки и изменения

В `tourism-backend` и `tourism-mobile` ветки создаются от свежей `gamma`, а
не от `main`, и MR открываются в `gamma`:

```bash
git fetch origin && git switch -c BACKEND-10 origin/gamma
glab mr create --source-branch BACKEND-10 --target-branch gamma
```

`gamma` сливается в `main` пачкой, когда выпускаем версию или выкатываем
бэкенд. Ветка задачи называется по ключу из трекера, порядок описан в
`docs/agent-tracker-workflow.md` суперпроекта.

В остальных репозиториях короткоживущие ветки от `main`. Предпочтительные
префиксы:

- `feat/`;
- `fix/`;
- `docs/`;
- `chore/`.

Коммиты должны быть небольшими и иметь понятную причину. Рекомендуется формат
Conventional Commits, например `docs: describe geography domain`.

## Pull request

Перед открытием pull request:

1. Выполните `./scripts/validate.sh` в затронутом repo (`make validate` для
   platform). GitLab CI по умолчанию **lean** и не гоняет style/tests.
2. Проверьте отсутствие секретов и случайных generated files.
3. Обновите документацию и ADR, если изменилось архитектурное решение.
4. Заполните summary и test plan в шаблоне pull request.

Изменение accepted ADR выполняется новым ADR, который заменяет предыдущее
решение, а не незаметным переписыванием истории.

## Local workspace

Repositories подключаются как Git submodules общего superproject. Изменения
сначала коммитятся и публикуются в дочернем repository, после чего superproject
обновляет соответствующий commit pointer. Используйте предусмотренные scripts
после создания remotes и не копируйте source между repositories.
