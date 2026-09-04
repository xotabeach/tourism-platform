#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

REQUIRED_FILES=(
  # Только то, что действительно лежит в репозитории. Внутренние документы
  # (планы, ранбуки, ревью, security-заметки) вынесены в .gitignore, и
  # требовать их здесь значило бы ломать проверку на чистом клоне.
  .editorconfig
  .env.example
  .gitignore
  .markdownlint-cli2.yaml
  .yamllint.yml
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/pull_request_template.md
  .gitlab-ci.yml
  .gitlab-ci.full.yml
  README.md
  CONTRIBUTING.md
  SECURITY.md
  LICENSE
  Makefile
  compose.yaml
  deploy/test/.env.example
  deploy/test/Caddyfile
  deploy/test/compose.yaml
  docs/product-vision.md
  docs/system-context.md
  docs/domain-model.md
  docs/application-business-logic.md
  docs/data-model-geography-places.md
  docs/data-model-routes.md
  docs/repository-strategy.md
  docs/local-development.md
  docs/development-conventions.md
  docs/development-environment.md
  docs/stack.md
  docs/python-code-style.md
  docs/python-testing-guide.md
  docs/flutter-code-style.md
  docs/flutter-testing-guide.md
  docs/flutter-app-architecture.md
  docs/flutter-design-system.md
  docs/decisions/ADR-001-modular-monolith-first.md
  docs/decisions/ADR-002-separate-mobile-backend-infrastructure-repositories.md
  docs/decisions/ADR-003-postgresql-postgis.md
  docs/decisions/ADR-004-routing-provider-abstraction.md
  docs/decisions/ADR-005-kafka-as-planned-event-backbone.md
  docs/decisions/ADR-006-ai-assisted-route-planning.md
  docs/decisions/ADR-007-authentication-and-session-strategy.md
  docs/decisions/ADR-010-2gis-routing-and-map-provider.md
  docs/decisions/ADR-011-personalized-route-recommendations.md
  scripts/bootstrap.sh
  scripts/bootstrap.ps1
  scripts/clone-repositories.sh
  scripts/clone-repositories.ps1
  scripts/validate.sh
  scripts/ci-mirror-to-github.sh
  scripts/deploy-test.sh
)

cd "${PROJECT_ROOT}"

for required_file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "${required_file}" ]]; then
    printf 'Ошибка: отсутствует обязательный файл %s\n' "${required_file}" >&2
    exit 1
  fi
done
printf 'Обязательные файлы: OK\n'

for shell_script in scripts/*.sh; do
  bash -n "${shell_script}"
done
printf 'Синтаксис shell-скриптов: OK\n'

if ! command -v docker >/dev/null 2>&1; then
  printf 'Ошибка: Docker необходим для проверки Compose.\n' >&2
  exit 1
fi
docker compose --env-file .env.example config --quiet
printf 'Docker Compose config: OK\n'
docker compose \
  --env-file deploy/test/.env.example \
  --file deploy/test/compose.yaml \
  config --quiet
printf 'Test deployment Compose config: OK\n'

# CI runs both linters unconditionally; skipping them locally would hide
# failures until the pipeline.
# Проверяем только то, что лежит в репозитории: внутренние документы вынесены
# в .gitignore, но остаются на диске у разработчика, и линтер спотыкался бы о
# файлы, которых в чистом клоне нет.
markdown_files=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r file; do
    markdown_files+=("${file}")
  done < <(git ls-files '*.md')
else
  while IFS= read -r file; do
    markdown_files+=("${file}")
  done < <(find . -name '*.md' -not -path './node_modules/*')
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  markdownlint-cli2 "${markdown_files[@]}"
elif command -v npx >/dev/null 2>&1; then
  npx --yes markdownlint-cli2@0.18.1 "${markdown_files[@]}"
else
  printf 'Ошибка: нужен markdownlint-cli2 или npx.\n' >&2
  exit 1
fi
printf 'Markdown lint: OK\n'

if command -v yamllint >/dev/null 2>&1; then
  yamllint .gitlab-ci.yml .gitlab-ci.full.yml .github compose.yaml
elif python3 -c 'import yamllint' >/dev/null 2>&1; then
  python3 -m yamllint .gitlab-ci.yml .gitlab-ci.full.yml .github compose.yaml
else
  printf 'Ошибка: нужен yamllint (pip install yamllint).\n' >&2
  exit 1
fi
printf 'YAML lint: OK\n'
