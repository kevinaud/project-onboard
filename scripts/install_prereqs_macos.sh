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
  if [ -z "${ONBOARD_BREW_PREFIX:-}" ]; then
    ONBOARD_BREW_PREFIX=$(_brew_prefix_for "${ONBOARD_OS}" "${ONBOARD_ARCH}")
    export ONBOARD_BREW_PREFIX
  fi
}

append_path_once() {
  if [ "$#" -ne 1 ]; then
    return 0
  fi

  local candidate="$1"
  if [ -z "${candidate}" ]; then
    return 0
  fi

  case ":${PATH}:" in
    *:"${candidate}":*)
      ;;
    *)
      PATH="${candidate}:${PATH}"
      export PATH
      log_verbose "Added ${candidate} to PATH"
      ;;
  esac
}

ensure_homebrew() {
  local brew_bin

  if command -v brew >/dev/null 2>&1; then
    brew_bin=$(command -v brew)
    log_info "Homebrew detected at ${brew_bin}"
  else
    if [ -z "${ONBOARD_BREW_PREFIX:-}" ]; then
      log_warn 'Unable to determine Homebrew prefix; defaulting to /usr/local'
      ONBOARD_BREW_PREFIX='/usr/local'
    fi
    log_info 'Homebrew not found; installing via official script.'
    local install_cmd
    # shellcheck disable=SC2016
    install_cmd='$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'
    run_cmd 'Install Homebrew' /bin/bash -c "${install_cmd}"
    brew_bin="${ONBOARD_BREW_PREFIX}/bin/brew"
  fi

  local brew_prefix
  brew_prefix=$(dirname "$(dirname "${brew_bin}")")
  export HOMEBREW_PREFIX="${brew_prefix}"

  append_path_once "${brew_prefix}/bin"
  append_path_once "${brew_prefix}/sbin"

  BREW_BIN="${brew_bin}"
}

install_prerequisites() {
  run_cmd 'Install macOS prerequisites via Homebrew (git, gh, chezmoi)' "${BREW_BIN}" install git gh chezmoi
}

main() {
  ensure_environment_loaded

  if [ "${ONBOARD_OS}" != 'macos' ]; then
    log_verbose 'macOS prerequisites script invoked on non-macOS host; skipping.'
    return 0
  fi

  ensure_homebrew
  install_prerequisites
}

main "$@"
