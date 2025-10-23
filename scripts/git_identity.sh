#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=utils.sh
. "${REPO_ROOT}/scripts/utils.sh"
# shellcheck source=detect.sh
. "${REPO_ROOT}/scripts/detect.sh"

ensure_environment_loaded() {
  if [ -z "${ONBOARD_OS:-}" ] || [ -z "${ONBOARD_ARCH:-}" ]; then
    load_environment_facts
  fi
}

require_git() {
  if ! command -v git >/dev/null 2>&1; then
    log_warn 'Git is not available on PATH; skipping identity prompts.'
    return 1
  fi
  return 0
}

prompt_for_nonempty_value() {
  local prompt_message="$1"
  local value=""

  while [ -z "${value}" ]; do
    value=$(prompt_for_input "${prompt_message}")
    if [ -z "${value}" ]; then
      log_warn 'Input cannot be empty.'
    fi
  done

  printf '%s\n' "${value}"
}

warn_manual_identity() {
  log_warn 'Global Git identity is not configured. Set it manually:'
  log_warn '  git config --global user.name "Your Name"'
  log_warn '  git config --global user.email "you@example.com"'
}

ensure_git_identity() {
  if ! require_git; then
    return 0
  fi

  local current_name
  local current_email
  current_name=$(git config --global user.name 2>/dev/null || true)
  current_email=$(git config --global user.email 2>/dev/null || true)

  if [ -n "${current_name}" ] && [ -n "${current_email}" ]; then
    log_info 'Global Git identity already configured.'
    return 0
  fi

  if [ "${ONBOARD_NON_INTERACTIVE}" = "1" ]; then
    warn_manual_identity
    return 0
  fi

  local new_name="${current_name}"
  local new_email="${current_email}"

  if [ -z "${new_name}" ]; then
    new_name=$(prompt_for_nonempty_value 'Enter your Git full name')
  fi

  if [ -z "${new_email}" ]; then
    new_email=$(prompt_for_nonempty_value 'Enter your Git email address')
  fi

  if [ -z "${new_name}" ] || [ -z "${new_email}" ]; then
    log_warn 'Git identity remains unset; skipping configuration.'
    return 0
  fi

  run_cmd 'Set global git user.name' git config --global user.name "${new_name}"
  run_cmd 'Set global git user.email' git config --global user.email "${new_email}"
}

main() {
  ensure_git_identity
}

main "$@"
