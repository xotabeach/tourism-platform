#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

REQUIRED_FILES=(
  .editorconfig
  .env.example
  .gitignore
  .markdownlint-cli2.yaml
  .yamllint.yml
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/pull_request_template.md
  .gitlab-ci.yml
  README.md
  CONTRIBUTING.md
  SECURITY.md
  LICENSE
  Makefile
  compose.yaml
  docs/legacy-project-analysis.md
  docs/product-vision.md
  docs/system-context.md
  docs/domain-model.md
  docs/repository-strategy.md
  docs/local-development.md
  docs/application-business-logic.md
  docs/implementation-plan.md
  docs/development-conventions.md
  docs/progress.md
  docs/data-model-geography-places.md
  docs/data-model-routes.md
  docs/ai-route-planning-architecture.md
  docs/python-code-style.md
  docs/python-testing-guide.md
  docs/flutter-code-style.md
  docs/flutter-testing-guide.md
  docs/flutter-app-architecture.md
  docs/development-environment.md
  docs/decisions/ADR-001-modular-monolith-first.md
  docs/decisions/ADR-002-separate-mobile-backend-infrastructure-repositories.md
  docs/decisions/ADR-003-postgresql-postgis.md
  docs/decisions/ADR-004-routing-provider-abstraction.md
  docs/decisions/ADR-005-kafka-as-planned-event-backbone.md
  docs/decisions/ADR-006-ai-assisted-route-planning.md
  docs/decisions/ADR-007-authentication-and-session-strategy.md
  docs/security/security-baseline.md
  docs/security/threat-model.md
  docs/security/data-classification-and-retention.md
  docs/security/authentication-and-token-security.md
  docs/security/backend-api-security.md
  docs/security/mobile-security.md
  docs/security/database-cache-storage-security.md
  docs/security/file-and-media-security.md
  docs/security/secrets-management.md
  docs/security/secure-development-lifecycle.md
  docs/security/security-testing-guide.md
  docs/security/security-incident-response.md
  docs/security/security-checklist.md
  docs/security/exceptions/README.md
  docs/security/audits/2026-07-23-security-audit.md
  docs/diagrams/container-diagram.md
  docs/diagrams/future-domain-services.md
  docs/diagrams/route-generation-flow.md
  docs/diagrams/phase-and-screens-map.md
  docs/events/event-catalog.md
  docs/repositories/tourism-platform.md
  docs/repositories/tourism-mobile.md
  docs/repositories/tourism-backend.md
  docs/repositories/tourism-infrastructure.md
  docs/repositories/tourism-documentation.md
  docs/services/identity.md
  docs/services/users.md
  docs/services/geography.md
  docs/services/places.md
  docs/services/routes.md
  docs/services/route-builder.md
  docs/services/media.md
  scripts/bootstrap.sh
  scripts/bootstrap.ps1
  scripts/clone-repositories.sh
  scripts/clone-repositories.ps1
  scripts/validate.sh
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

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  markdownlint-cli2 "**/*.md"
  printf 'Markdown lint: OK\n'
else
  printf 'Markdown lint: SKIP (markdownlint-cli2 не установлен)\n'
fi

if command -v yamllint >/dev/null 2>&1; then
  yamllint .gitlab-ci.yml .github compose.yaml
  printf 'YAML lint: OK\n'
else
  printf 'YAML lint: SKIP (yamllint не установлен)\n'
fi
