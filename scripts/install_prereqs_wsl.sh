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

update_package_cache() {
  run_cmd 'Update package cache' sudo apt-get update
}

install_prerequisites() {
  run_cmd 'Install WSL prerequisites via apt (git, gh, curl, chezmoi)' \
    sudo apt-get install -y git gh curl chezmoi
}

main() {
  ensure_environment_loaded

  if [ "${ONBOARD_IS_WSL}" != "1" ]; then
    log_verbose 'WSL prerequisites script invoked on non-WSL host; skipping.'
    return 0
  fi

  update_package_cache
  install_prerequisites
}

main "$@"
