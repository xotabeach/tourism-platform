#!/usr/bin/env bash

set -Eeuo pipefail

# Host-level cron entrypoint for the nightly achievement catch-up.
# The job is a short-lived Compose task, not a resident scheduler process.
# Newly earned achievements can send FCM push after their transaction commits.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_DIR="${ACHIEVEMENTS_DEPLOY_DIR:-${PROJECT_ROOT}/deploy/test}"
ENV_FILE="${ACHIEVEMENTS_ENV_FILE:-${TEST_ENV_FILE:-${DEPLOY_DIR}/.env}}"
LOCK_FILE="${ACHIEVEMENTS_LOCK_FILE:-/tmp/crimeatrip-achievements.lock}"

if [[ ! -f "${ENV_FILE}" ]]; then
  printf 'Error: achievement environment file not found: %s\n' "${ENV_FILE}" >&2
  exit 1
fi

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  printf 'Achievement catch-up is already running; skipping this invocation.\n'
  exit 0
fi

compose=(
  docker compose
  --env-file "${ENV_FILE}"
  --file "${DEPLOY_DIR}/compose.yaml"
  --profile maintenance
  run
  --rm
  achievements
)

set +e
"${compose[@]}"
status=$?
set -e

if (( status != 0 )); then
  # syslog is deliberately best-effort: cron still receives the non-zero exit
  # code and can mail/monitor stderr when logger is unavailable.
  logger -p daemon.err -t crimeatrip-achievements \
    "achievement catch-up failed with exit code ${status}" 2>/dev/null || true
  exit "${status}"
fi
