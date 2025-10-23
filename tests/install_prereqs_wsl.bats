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

@test "install_prereqs_wsl runs apt-get update and install on WSL" {
  run env ONBOARD_OS=wsl ONBOARD_ARCH=x86_64 ONBOARD_IS_WSL=1 "${TEST_ROOT}/scripts/install_prereqs_wsl.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] DRY-RUN: Update package cache: sudo apt-get update'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Install WSL prerequisites via apt (git, gh, curl, chezmoi): sudo apt-get install -y git gh curl chezmoi'* ]]
}

@test "install_prereqs_wsl respects dry-run mode" {
  run env ONBOARD_OS=wsl ONBOARD_ARCH=x86_64 ONBOARD_IS_WSL=1 ONBOARD_DRY_RUN=1 "${TEST_ROOT}/scripts/install_prereqs_wsl.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'DRY-RUN'* ]]
}
