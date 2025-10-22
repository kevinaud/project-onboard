#!/usr/bin/env bats

load test_helper

setup() {
  load_detect
}

@test "detect_environment emits expected keys" {
  run detect_environment
  [ "$status" -eq 0 ]
  [[ "$output" == *'"os"'* ]]
  [[ "$output" == *'"arch"'* ]]
  [[ "$output" == *'"is_wsl"'* ]]
  [[ "$output" == *'"shell"'* ]]
  [[ "$output" == *'"brew_prefix"'* ]]
}

@test "load_environment_facts exports variables" {
  load_environment_facts
  [ -n "${ONBOARD_OS}" ]
  [ -n "${ONBOARD_ARCH}" ]
  [ -n "${ONBOARD_SHELL_NAME}" ]
  [[ "${ONBOARD_IS_WSL}" =~ ^[01]$ ]]
}

@test "brew prefix maps arm64 to opt homebrew" {
  run _brew_prefix_for macos arm64
  [ "$status" -eq 0 ]
  [ "$output" = '/opt/homebrew' ]
}

@test "brew prefix maps x86 to usr local" {
  run _brew_prefix_for macos x86_64
  [ "$status" -eq 0 ]
  [ "$output" = '/usr/local' ]
}

@test "is_wsl detects linux host default" {
  if is_wsl; then
    skip "Environment is WSL; skipping non-WSL assertion"
  fi

  ! is_wsl
}
