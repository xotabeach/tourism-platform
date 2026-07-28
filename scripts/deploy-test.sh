#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_DIR="${PROJECT_ROOT}/deploy/test"
ENV_FILE="${TEST_ENV_FILE:-${DEPLOY_DIR}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  printf 'Error: test environment file not found: %s\n' "${ENV_FILE}" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "${ENV_FILE}")" != "600" ]]; then
  printf 'Error: %s must have mode 600.\n' "${ENV_FILE}" >&2
  exit 1
fi

if [[ "$#" -ne 1 ]]; then
  printf 'Usage: %s <immutable-backend-image>\n' "$0" >&2
  exit 1
fi

export BACKEND_IMAGE="$1"
compose=(
  docker compose
  --env-file "${ENV_FILE}"
  --file "${DEPLOY_DIR}/compose.yaml"
)

"${compose[@]}" config --quiet
"${compose[@]}" pull caddy postgres redis backend
"${compose[@]}" up --detach postgres redis
"${compose[@]}" run --rm migrate
if [[ "${DEPLOY_SEED:-false}" == "true" ]]; then
  "${compose[@]}" run --rm seed
fi
"${compose[@]}" up --detach --remove-orphans --wait
"${compose[@]}" ps

printf 'Test deployment is healthy.\n'
