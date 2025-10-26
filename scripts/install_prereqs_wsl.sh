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
}

update_package_cache() {
  run_cmd 'Update package cache' sudo apt-get update
}

install_prerequisites() {
  run_cmd 'Install WSL prerequisites via apt (git, gh, curl, chezmoi, python3)' \
    sudo apt-get install -y git gh curl chezmoi python3
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    log_info 'Visual Studio Code already installed.'
    return 0
  fi

  local arch_token='x64'
  case "$(uname -m)" in
    aarch64|arm64)
      arch_token='arm64'
      ;;
  esac

  local temp_deb
  temp_deb=$(mktemp /tmp/vscode-XXXXXX.deb)

  run_cmd 'Download Visual Studio Code .deb' curl -L "https://update.code.visualstudio.com/latest/linux-deb-${arch_token}/stable" -o "${temp_deb}"
  run_cmd 'Install Visual Studio Code' sudo apt-get install -y "${temp_deb}"
  run_cmd 'Remove Visual Studio Code installer' rm -f "${temp_deb}"
}

install_remote_extension_pack() {
  if command -v code >/dev/null 2>&1; then
    run_cmd 'Install VS Code Remote Development extension pack' code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force
    return 0
  fi

  if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
    log_info 'DRY-RUN: Install VS Code Remote Development extension pack: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'
  else
    log_warn 'VS Code CLI not found; skipping Remote Development extension installation.'
  fi
}

configure_vscode_dotfiles() {
  local settings_path="${HOME}/.config/Code/User/settings.json"

  if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
    log_info "DRY-RUN: Ensure VS Code settings at ${settings_path} configure kevinaud/dotfiles as the dev container dotfiles repository."
    return 0
  fi

  local python_bin=""
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

  if [ "${ONBOARD_IS_WSL}" != "1" ]; then
    log_verbose 'WSL prerequisites script invoked on non-WSL host; skipping.'
    return 0
  fi

  update_package_cache
  install_prerequisites
  install_vscode
  install_remote_extension_pack
  configure_vscode_dotfiles
}

main "$@"
