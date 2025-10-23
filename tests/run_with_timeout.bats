#!/usr/bin/env bats
# tests/run_with_timeout.bats

load test_helper

setup() {
  setup_test_environment
}

teardown() {
  teardown_test_environment
}

@test "run_with_timeout executes command successfully" {
  run "${REPO_ROOT}/scripts/run_with_timeout.sh" 5 -- bash -c 'echo done'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Running with timeout 5s"* ]]
  [[ "$output" == *"done"* ]]
}

@test "run_with_timeout enforces timeout" {
  run "${REPO_ROOT}/scripts/run_with_timeout.sh" 1 -- bash -c 'sleep 2'
  [ "$status" -eq 124 ]
  [[ "$output" == *"Command timed out after 1s"* ]]
}

@test "run_with_timeout requires a command" {
  run "${REPO_ROOT}/scripts/run_with_timeout.sh"
  [ "$status" -eq 64 ]
  [[ "$output" == *"Usage:"* ]]
}
