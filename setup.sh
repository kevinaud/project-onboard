#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}" && pwd)

# shellcheck source=scripts/utils.sh
. "${REPO_ROOT}/scripts/utils.sh"
# shellcheck source=scripts/detect.sh
. "${REPO_ROOT}/scripts/detect.sh"

print_usage() {
  cat <<'USAGE'
Usage: setup.sh [options]

Options:
  --dry-run           Print planned actions only (default; enforced during early iterations)
  --non-interactive   Assume default answers to prompts
  --no-optional       Skip optional tasks even if prompted later
  --verbose           Enable verbose logging
  --workspace <path>  Override default workspace directory (default: ~/projects)
  --help              Show this help message
USAGE
}

parse_flags() {
  local positional=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        ONBOARD_DRY_RUN=1
        ;;
      --non-interactive)
        ONBOARD_NON_INTERACTIVE=1
        ;;
      --no-optional)
        ONBOARD_NO_OPTIONAL=1
        ;;
      --verbose)
        ONBOARD_VERBOSE=1
        ;;
      --workspace)
        if [ "$#" -lt 2 ]; then
          log_error '--workspace requires a path argument'
          exit 1
        fi
        shift
        ONBOARD_WORKSPACE_DIR=$1
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      --)
        shift
        positional+=("$@")
        break
        ;;
      -* )
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
      * )
        positional+=("$1")
        ;;
    esac
    shift
  done

  if [ "${#positional[@]}" -gt 0 ]; then
    log_warn "Ignoring positional arguments: ${positional[*]}"
  fi

  export ONBOARD_VERBOSE ONBOARD_NON_INTERACTIVE ONBOARD_DRY_RUN ONBOARD_NO_OPTIONAL ONBOARD_WORKSPACE_DIR
}

report_environment() {
  load_environment_facts
  local wsl_note='no'
  if [ "${ONBOARD_IS_WSL}" -eq 1 ]; then
    wsl_note='yes'
  fi

  log_info "Detected OS: ${ONBOARD_OS}"
  log_info "Architecture: ${ONBOARD_ARCH}"
  log_info "Shell: ${ONBOARD_SHELL_NAME}"
  log_info "Running under WSL: ${wsl_note}"

  if [ -n "${ONBOARD_BREW_PREFIX}" ]; then
    log_info "Homebrew prefix suggestion: ${ONBOARD_BREW_PREFIX}"
  else
    log_verbose 'Homebrew prefix not applicable on this host'
  fi

  if [ "${ONBOARD_VERBOSE}" = "1" ]; then
    log_verbose "Environment JSON: $(detect_environment)"
  fi
}

main() {
  parse_flags "$@"

  local plan=(
    'Detect host platform information and print environment summary'
    'Ensure macOS or WSL prerequisites (Homebrew/apt, git, gh, chezmoi) are available when needed'
    'Verify Git global identity and prompt when unset'
    'Apply minimal project-required .gitconfig via chezmoi templates with safe backup'
    'Authenticate with GitHub (macOS: gh auth login; WSL: uses Windows GCM)'
    'Clone or update the private project repository'
    'Keep dry-run guardrails in place (no host changes will be made)'
  )

  announce_plan "${plan[@]}"
  report_environment

  if [ "${ONBOARD_OS}" = 'macos' ]; then
    "${REPO_ROOT}/scripts/install_prereqs_macos.sh"
    "${REPO_ROOT}/scripts/git_identity.sh"
    "${REPO_ROOT}/scripts/git_config_minimum.sh"
    "${REPO_ROOT}/scripts/gh_auth.sh"
    "${REPO_ROOT}/scripts/clone_project.sh"
  elif [ "${ONBOARD_IS_WSL}" -eq 1 ]; then
    "${REPO_ROOT}/scripts/install_prereqs_wsl.sh"
    "${REPO_ROOT}/scripts/git_identity.sh"
    "${REPO_ROOT}/scripts/git_config_minimum.sh"
    log_verbose 'Skipping GitHub authentication on WSL (uses Windows GCM)'
    "${REPO_ROOT}/scripts/clone_project.sh"
    "${REPO_ROOT}/scripts/docker_verify_wsl.sh"
  else
    log_verbose 'Platform-specific onboarding steps skipped on this platform.'
  fi

  log_info 'Dry-run enforced; no host changes were attempted.'
}

main "$@"
