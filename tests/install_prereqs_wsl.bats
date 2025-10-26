#!/usr/bin/env bats

load test_helper

setup() {
  load_utils
}

@test "install_prereqs_wsl skips on non-WSL hosts" {
  run env ONBOARD_OS=macos ONBOARD_ARCH=arm64 ONBOARD_IS_WSL=0 "${TEST_ROOT}/scripts/install_prereqs_wsl.sh"
  [ "$status" -eq 0 ]
  [ -z "${output}" ]
}

@test "install_prereqs_wsl prints planned apt-get operations in dry-run mode" {
  run env ONBOARD_OS=wsl ONBOARD_ARCH=x86_64 ONBOARD_IS_WSL=1 ONBOARD_DRY_RUN=1 PATH="/usr/local/bin:/usr/bin:/bin" "${TEST_ROOT}/scripts/install_prereqs_wsl.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] DRY-RUN: Update package cache: sudo apt-get update'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install WSL prerequisites via apt (git, gh, curl, chezmoi, python3): sudo apt-get install -y git gh curl chezmoi python3'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Download Visual Studio Code .deb: curl -L https://update.code.visualstudio.com/latest/linux-deb-x64/stable -o'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install Visual Studio Code: sudo apt-get install -y '* ]]
  [[ "${output}" == *'DRY-RUN: Install VS Code Remote Development extension pack: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'* ]]
  [[ "${output}" == *'DRY-RUN: Ensure VS Code settings at '*'/settings.json configure kevinaud/dotfiles as the dev container dotfiles repository.'* ]]
}

@test "install_prereqs_wsl respects dry-run mode" {
  run env ONBOARD_OS=wsl ONBOARD_ARCH=x86_64 ONBOARD_IS_WSL=1 ONBOARD_DRY_RUN=1 PATH="/usr/local/bin:/usr/bin:/bin" "${TEST_ROOT}/scripts/install_prereqs_wsl.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'DRY-RUN'* ]]
}
