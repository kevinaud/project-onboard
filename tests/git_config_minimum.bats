#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_environment
  export SCRIPT_DIR="${REPO_ROOT}/scripts"
  export GIT_CONFIG_SCRIPT="${SCRIPT_DIR}/git_config_minimum.sh"
}

teardown() {
  teardown_test_environment
}

@test "git_config_minimum.sh: skips on missing .gitconfig in dry-run" {
  [ ! -f "${HOME}/.gitconfig" ]
  
  run "${GIT_CONFIG_SCRIPT}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No existing .gitconfig found" ]]
  [[ "$output" =~ "DRY-RUN: Would apply chezmoi templates" ]]
}

@test "git_config_minimum.sh: logs backup and prompt intent when .gitconfig exists in dry-run" {
  echo "[user]
	name = Existing User" > "${HOME}/.gitconfig"
  
  run "${GIT_CONFIG_SCRIPT}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Existing .gitconfig detected" ]]
  [[ "$output" =~ "DRY-RUN: Would create backup" ]]
  [[ "$output" =~ "DRY-RUN: Would prompt" ]]
  [[ "$output" =~ "DRY-RUN: Would apply chezmoi templates from" ]]
}

@test "git_config_minimum.sh: uses correct source path for chezmoi" {
  run "${GIT_CONFIG_SCRIPT}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY-RUN: Would apply chezmoi templates from ${REPO_ROOT}/min-dotfiles" ]]
}
