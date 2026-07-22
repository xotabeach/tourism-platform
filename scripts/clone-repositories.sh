#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SUPERPROJECT_ROOT="$(cd -- "${PROJECT_ROOT}/.." && pwd)"
GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"
GITLAB_NAMESPACE="${GITLAB_NAMESPACE:-travel-platform2}"
GITLAB_BASE_URL="https://${GITLAB_HOST}/${GITLAB_NAMESPACE}"
REPOSITORIES=(
  tourism-mobile
  tourism-backend
  tourism-infrastructure
  tourism-documentation
)

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Ошибка: обязательная команда "%s" не найдена.\n' "${command_name}" >&2
    exit 1
  fi
}

require_command git
require_command glab

if ! git -C "${PROJECT_ROOT}" rev-parse --show-toplevel >/dev/null 2>&1; then
  printf 'Ошибка: %s не является Git-репозиторием.\n' "${PROJECT_ROOT}" >&2
  exit 1
fi

if [[ "$(git -C "${SUPERPROJECT_ROOT}" rev-parse --show-toplevel 2>/dev/null)" != \
  "${SUPERPROJECT_ROOT}" ]]; then
  printf 'Ошибка: %s не является Git superproject.\n' "${SUPERPROJECT_ROOT}" >&2
  exit 1
fi

if ! glab auth status --hostname "${GITLAB_HOST}" >/dev/null 2>&1; then
  printf 'Ошибка: GitLab CLI не авторизован. Выполните "glab auth login".\n' >&2
  exit 1
fi

printf 'Проверка репозиториев namespace %s...\n' "${GITLAB_NAMESPACE}"
for repository in "${REPOSITORIES[@]}"; do
  target="${SUPERPROJECT_ROOT}/${repository}"
  if [[ -e "${target}" ]]; then
    printf 'Пропуск %s: каталог уже существует и не будет перезаписан.\n' "${target}"
    continue
  fi

  if ! glab api "projects/${GITLAB_NAMESPACE}%2F${repository}" >/dev/null 2>&1; then
    printf 'Ошибка: репозиторий %s/%s недоступен или ещё не создан.\n' \
      "${GITLAB_NAMESPACE}" "${repository}" >&2
    exit 1
  fi
done

for repository in "${REPOSITORIES[@]}"; do
  target="${SUPERPROJECT_ROOT}/${repository}"
  if [[ -e "${target}" ]]; then
    continue
  fi

  printf 'Добавление submodule %s...\n' "${repository}"
  if ! git -C "${SUPERPROJECT_ROOT}" submodule add \
    "${GITLAB_BASE_URL}/${repository}.git" \
    "${repository}"; then
    printf 'Ошибка: не удалось добавить submodule %s/%s.\n' \
      "${GITLAB_NAMESPACE}" "${repository}" >&2
    exit 1
  fi
done

printf 'Готово. Проверьте .gitmodules и submodule pointers в %s.\n' \
  "${SUPERPROJECT_ROOT}"
