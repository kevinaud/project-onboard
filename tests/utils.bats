#!/usr/bin/env bats

load test_helper

setup() {
  load_utils
}

@test "generate_backup_path appends timestamp" {
  run generate_backup_path "/tmp/example"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^/tmp/example\.bak\.[0-9]{8}-[0-9]{6}$ ]]
}

@test "run_cmd respects dry-run" {
  local target="${BATS_TEST_TMPDIR}/dry-run-file"
  run run_cmd "create file" touch "$target"
  [ "$status" -eq 0 ]
  [[ "$output" == "[INFO] DRY-RUN: create file: touch ${target}" ]]
  [ ! -e "$target" ]
}

@test "run_cmd executes command when dry-run disabled" {
  ONBOARD_DRY_RUN=0
  export ONBOARD_DRY_RUN

  local target="${BATS_TEST_TMPDIR}/live-file"
  run run_cmd "write file" bash -c "printf 'hello' > '$target'"
  [ "$status" -eq 0 ]
  [[ "$output" == "[INFO] write file"* ]]
  [ -f "$target" ]
  run cat "$target"
  [ "$status" -eq 0 ]
  [ "$output" = 'hello' ]
}

@test "confirm honours non-interactive default yes" {
  ONBOARD_NON_INTERACTIVE=1
  export ONBOARD_NON_INTERACTIVE
  run confirm "Proceed?" yes
  [ "$status" -eq 0 ]
}

@test "confirm honours non-interactive default no" {
  ONBOARD_NON_INTERACTIVE=1
  export ONBOARD_NON_INTERACTIVE
  run confirm "Proceed?" no
  [ "$status" -eq 1 ]
}
