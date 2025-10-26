#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=./utils.sh
. "${REPO_ROOT}/scripts/utils.sh"
# shellcheck source=./detect.sh
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

install_vscode() {
  if command -v code >/dev/null 2>&1 || [ -d "/Applications/Visual Studio Code.app" ]; then
    log_info 'Visual Studio Code already installed.'
    return 0
  fi

  run_cmd 'Install Visual Studio Code via Homebrew' "${BREW_BIN}" install --cask visual-studio-code
}

find_code_cli() {
  if command -v code >/dev/null 2>&1; then
    command -v code
    return 0
  fi

  local default_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if [ -x "${default_cli}" ]; then
    printf '%s\n' "${default_cli}"
    return 0
  fi

  return 1
}

install_remote_extension_pack() {
  local code_cli
  if ! code_cli=$(find_code_cli); then
    if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
      log_info 'DRY-RUN: Install VS Code Remote Development extension pack: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'
      return 0
    fi

    log_warn 'Unable to locate VS Code CLI; skipping Remote Development extension installation.'
    return 0
  fi

  run_cmd 'Install VS Code Remote Development extension pack' "${code_cli}" --install-extension ms-vscode-remote.vscode-remote-extensionpack --force
}

configure_vscode_dotfiles() {
  local settings_path="${HOME}/Library/Application Support/Code/User/settings.json"
  local python_bin=""

  if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
    log_info "DRY-RUN: Ensure VS Code settings at ${settings_path} configure kevinaud/dotfiles as the dev container dotfiles repository."
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python_bin=python3
  elif command -v python >/dev/null 2>&1; then
    python_bin=python
  else
    log_warn 'Python interpreter not available; unable to update VS Code settings.'
    return 0
  fi

  set +e
  "${python_bin}" - "${settings_path}" <<'PY'
import json
import pathlib
import re
import sys

DEFAULTS = {
    "dotfiles.repository": "kevinaud/dotfiles",
    "dotfiles.targetPath": "~/dotfiles",
    "dotfiles.installCommand": "install.sh",
}

COMMENT_PATTERN = re.compile(r"//.*?$|/\*.*?\*/", re.DOTALL | re.MULTILINE)


def load_settings(path: pathlib.Path) -> dict:
    if not path.exists():
        return {}

    raw = path.read_text(encoding="utf-8")
    if not raw.strip():
        return {}

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        stripped = COMMENT_PATTERN.sub("", raw)
        return json.loads(stripped)


def ensure_defaults(path: pathlib.Path) -> int:
    settings = load_settings(path)
    changed = False

    for key, value in DEFAULTS.items():
        if key not in settings:
            settings[key] = value
            changed = True

    if changed:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(settings, indent=4) + "\n", encoding="utf-8")
        return 1

    return 0


def main() -> int:
    if len(sys.argv) < 2:
        return 3

    path = pathlib.Path(sys.argv[1]).expanduser()
    try:
        return ensure_defaults(path)
    except json.JSONDecodeError:
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
PY
  status=$?
  set -e

  case ${status} in
    0)
      log_info 'VS Code settings already configure kevinaud/dotfiles.'
      ;;
    1)
      log_info 'VS Code settings updated to configure kevinaud/dotfiles.'
      ;;
    2)
      log_warn 'Existing VS Code settings could not be parsed; please update manually.'
      ;;
    *)
      log_warn "VS Code settings update exited with status ${status}."
      ;;
  esac
}

main() {
  ensure_environment_loaded

  if [ "${ONBOARD_OS}" != 'macos' ]; then
    log_verbose 'macOS prerequisites script invoked on non-macOS host; skipping.'
    return 0
  fi

  ensure_homebrew
  install_prerequisites
  install_vscode
  install_remote_extension_pack
  configure_vscode_dotfiles
}

main "$@"
