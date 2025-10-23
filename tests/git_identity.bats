#!/usr/bin/env bats

load test_helper

setup() {
  load_utils
}

@test "git identity warns in non-interactive mode" {
  local fake_home="${BATS_TEST_TMPDIR}/home-noninteractive"
  mkdir -p "${fake_home}"

  run env HOME="${fake_home}" ONBOARD_OS=macos ONBOARD_NON_INTERACTIVE=1 "${TEST_ROOT}/scripts/git_identity.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[WARN] Global Git identity is not configured. Set it manually:'* ]]
  [[ "${output}" == *'[WARN]   git config --global user.name "Your Name"'* ]]
  [[ "${output}" == *'[WARN]   git config --global user.email "you@example.com"'* ]]
}

@test "git identity prompts for missing values" {
  local fake_home="${BATS_TEST_TMPDIR}/home-interactive"
  mkdir -p "${fake_home}"

  run env HOME="${fake_home}" ONBOARD_OS=macos "${TEST_ROOT}/scripts/git_identity.sh" <<'EOF'
Alice Example
alice@example.com
EOF
  [ "$status" -eq 0 ]
  [[ "${output}" == *'Enter your Git full name'* ]]
  [[ "${output}" == *'Enter your Git email address'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Set global git user.name: git config --global user.name Alice Example'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Set global git user.email: git config --global user.email alice@example.com'* ]]
}

@test "git identity skips when already configured" {
  local fake_home="${BATS_TEST_TMPDIR}/home-configured"
  mkdir -p "${fake_home}"
  HOME="${fake_home}" git config --global user.name "Existing User"
  HOME="${fake_home}" git config --global user.email "existing@example.com"

  run env HOME="${fake_home}" ONBOARD_OS=macos "${TEST_ROOT}/scripts/git_identity.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] Global Git identity already configured.'* ]]
  [[ "${output}" != *'DRY-RUN: Set global git user.name'* ]]
}
