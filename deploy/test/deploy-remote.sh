#!/usr/bin/env bash
# Remote test-contour deploy. Runs on the server under a restricted deploy user.
# Usage: deploy-remote.sh <immutable-backend-image-ref>
# Set DEPLOY_SKIP_PULL=true only when the exact image was loaded over the
# pinned SSH connection immediately before this script is called.
#
# Example:
#   ./deploy-remote.sh registry.gitlab.com/travel-platform2/tourism-backend:<sha>

set -Eeuo pipefail

if [[ "${#}" -ne 1 ]]; then
  printf 'Usage: %s <immutable-backend-image>\n' "$(basename "$0")" >&2
  exit 1
fi

IMAGE="$1"
# По умолчанию — каталог самого скрипта: путь на сервере в репозитории не
# хранится, а лежать рядом с compose.yaml он и так обязан.
DEPLOY_DIR="${DEPLOY_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
ENV_FILE="${TEST_ENV_FILE:-${DEPLOY_DIR}/.env}"
COMPOSE=(docker compose --env-file "${ENV_FILE}" --file "${DEPLOY_DIR}/compose.yaml")

if [[ ! -f "${ENV_FILE}" ]]; then
  printf 'Error: env file not found: %s\n' "${ENV_FILE}" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "${ENV_FILE}")" != "600" ]]; then
  printf 'Error: %s must have mode 600.\n' "${ENV_FILE}" >&2
  exit 1
fi

case "${IMAGE}" in
  registry.gitlab.com/*:* ) ;;
  *)
    printf 'Error: refuse non-registry image ref: %s\n' "${IMAGE}" >&2
    exit 1
    ;;
esac

cd "${DEPLOY_DIR}"

if [[ "${DEPLOY_SKIP_PULL:-false}" == "true" ]]; then
  if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    printf 'Error: local image is missing while DEPLOY_SKIP_PULL=true: %s\n' \
      "${IMAGE}" >&2
    exit 1
  fi
elif [[ "${DEPLOY_SKIP_PULL:-false}" != "false" ]]; then
  printf 'Error: DEPLOY_SKIP_PULL must be true or false.\n' >&2
  exit 1
fi

PREVIOUS="$(awk -F= '/^BACKEND_IMAGE=/{print $2; exit}' "${ENV_FILE}" || true)"
printf 'Deploying backend image: %s\n' "${IMAGE}"
if [[ -n "${PREVIOUS}" ]]; then
  printf 'Previous image: %s\n' "${PREVIOUS}"
fi

tmp_env="$(mktemp)"
trap 'rm -f "${tmp_env}"' EXIT
awk -v image="${IMAGE}" '
  BEGIN { updated=0 }
  /^BACKEND_IMAGE=/ { print "BACKEND_IMAGE=" image; updated=1; next }
  { print }
  END { if (!updated) print "BACKEND_IMAGE=" image }
' "${ENV_FILE}" > "${tmp_env}"
chmod 600 "${tmp_env}"
mv "${tmp_env}" "${ENV_FILE}"
trap - EXIT

# Sync AI-provider secrets from CI/CD variables into the server .env, so they
# are edited once in GitLab (Settings → CI/CD → Variables, masked+protected)
# rather than by hand over SSH. Each key syncs only when the caller actually
# passed it in the environment — an unset key here leaves the existing .env
# line untouched instead of blanking it. Value is read via ENVIRON, not -v,
# so the secret never appears in this process's argv.
SYNCED_ENV_KEYS=(DEEPSEEK_API_KEY GEMINI_API_KEY LM_STUDIO_API_KEY AI_PROVIDER)
for sync_key in "${SYNCED_ENV_KEYS[@]}"; do
  if [[ -n "${!sync_key:-}" ]]; then
    tmp_env="$(mktemp)"
    trap 'rm -f "${tmp_env}"' EXIT
    awk -v k="${sync_key}" '
      BEGIN { updated=0; pat="^" k "="; v=ENVIRON[k] }
      $0 ~ pat { print k "=" v; updated=1; next }
      { print }
      END { if (!updated) print k "=" v }
    ' "${ENV_FILE}" > "${tmp_env}"
    chmod 600 "${tmp_env}"
    mv "${tmp_env}" "${ENV_FILE}"
    trap - EXIT
  fi
done

# Ensure media volume is writable by appuser (uid 10001).
if docker volume inspect crimeatrip-test_media-data >/dev/null 2>&1; then
  docker run --rm -v crimeatrip-test_media-data:/data alpine:3.21 \
    chown -R 10001:10001 /data
fi

if [[ "${DEPLOY_SKIP_PULL:-false}" != "true" ]]; then
  "${COMPOSE[@]}" pull backend
fi
"${COMPOSE[@]}" up --detach postgres redis
"${COMPOSE[@]}" --profile tools run --rm migrate
"${COMPOSE[@]}" up --detach --force-recreate --no-deps backend

printf 'Waiting for backend container health\n'
ready=0
for _ in $(seq 1 36); do
  cid="$("${COMPOSE[@]}" ps -q backend || true)"
  if [[ -n "${cid}" ]]; then
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${cid}" 2>/dev/null || true)"
    if [[ "${status}" == "healthy" ]]; then
      ready=1
      break
    fi
  fi
  sleep 5
done

if [[ "${ready}" -ne 1 ]]; then
  printf 'Error: backend did not become healthy.\n' >&2
  "${COMPOSE[@]}" ps
  cid="$("${COMPOSE[@]}" ps -q backend || true)"
  if [[ -n "${cid}" ]]; then
    docker logs --tail 80 "${cid}" >&2 || true
  fi
  exit 1
fi

if [[ -n "${DEPLOY_HEALTH_URL:-}" ]]; then
  printf 'Public smoke: %s\n' "${DEPLOY_HEALTH_URL}"
  curl -fsS -m 10 "${DEPLOY_HEALTH_URL}" | grep -q '"status":"ready"'
fi

"${COMPOSE[@]}" ps
printf 'Test deployment is healthy: %s\n' "${IMAGE}"
