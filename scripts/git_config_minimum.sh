#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=scripts/utils.sh
. "${REPO_ROOT}/scripts/utils.sh"

# Apply minimal project-required .gitconfig using chezmoi templates.
# Ensures backup safety and prompts when overwriting existing configs.

apply_minimal_gitconfig() {
  local gitconfig_path="${HOME}/.gitconfig"
  local backup_path

  log_info 'Checking for existing .gitconfig...'

  if [ -f "${gitconfig_path}" ]; then
    log_info 'Existing .gitconfig detected'

    if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
      backup_path=$(generate_backup_path "${gitconfig_path}")
      log_info "DRY-RUN: Would create backup at ${backup_path}"
      log_info "DRY-RUN: Would prompt: 'A .gitconfig already exists. We need to apply a minimal configuration. May we proceed? (This will back up your original file.)'"
      log_info "DRY-RUN: Would apply chezmoi templates from ${REPO_ROOT}/min-dotfiles"
      return 0
    fi

    if ! confirm "A .gitconfig already exists. We need to apply a minimal configuration. May we proceed? (This will back up your original file.)" "yes"; then
      log_error 'User declined .gitconfig overwrite; cannot proceed with minimal Git configuration'
      exit 1
    fi

    backup_path=$(generate_backup_path "${gitconfig_path}")
    log_info "Creating backup: ${backup_path}"
    cp "${gitconfig_path}" "${backup_path}"
  else
    log_info 'No existing .gitconfig found; will create new file'

    if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
      log_info "DRY-RUN: Would apply chezmoi templates from ${REPO_ROOT}/min-dotfiles"
      return 0
    fi
  fi

  log_info "Applying minimal Git configuration via chezmoi from ${REPO_ROOT}/min-dotfiles"
  run_cmd 'Initialize and apply chezmoi templates' \
    chezmoi init --apply --source-path "${REPO_ROOT}/min-dotfiles"

  log_info 'Minimal .gitconfig applied successfully'
}

main() {
  apply_minimal_gitconfig
}

main "$@"
