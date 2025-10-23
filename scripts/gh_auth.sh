#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=scripts/utils.sh
. "${REPO_ROOT}/scripts/utils.sh"

# Perform GitHub authentication for macOS and native Linux
# WSL authentication is handled via Windows GCM, so this script is skipped for WSL
authenticate_github() {
  log_info 'Checking GitHub authentication status...'

  if gh auth status >/dev/null 2>&1; then
    log_info 'GitHub authentication already configured.'
    return 0
  fi

  if [ "${ONBOARD_NON_INTERACTIVE}" = "1" ]; then
    log_warn 'GitHub authentication required but running in non-interactive mode.'
    log_warn 'Please run: gh auth login --web --git-protocol https'
    return 1
  fi

  log_info 'Initiating GitHub authentication...'
  log_info 'A browser window will open for authentication.'

  if ! run_cmd 'Authenticate with GitHub' gh auth login --web --git-protocol https; then
    log_error 'GitHub authentication failed.'
    log_error 'Troubleshooting steps:'
    log_error '  - Check your internet connection'
    log_error '  - Ensure your browser is accessible'
    log_error '  - Retry with: gh auth login --web --git-protocol https'
    return 1
  fi

  # In dry-run mode, we can't verify auth status, so just return success
  if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
    return 0
  fi

  if gh auth status >/dev/null 2>&1; then
    log_info 'GitHub authentication successful.'
    return 0
  else
    log_error 'GitHub authentication status check failed.'
    return 1
  fi
}

# Main execution
authenticate_github
