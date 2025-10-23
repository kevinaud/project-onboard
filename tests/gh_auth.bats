#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_environment
  
  # Mock gh binary
  export PATH="${TEST_TEMP_DIR}/bin:${PATH}"
  mkdir -p "${TEST_TEMP_DIR}/bin"
  
  # Default mock: gh not authenticated
  cat > "${TEST_TEMP_DIR}/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  if [ "${GH_AUTH_MOCK_STATUS:-1}" = "0" ]; then
    echo "✓ Logged in to github.com as test-user"
    exit 0
  else
    echo "You are not logged in to any GitHub hosts. Run gh auth login to authenticate."
    exit 1
  fi
elif [ "$1" = "auth" ] && [ "$2" = "login" ]; then
  if [ "${GH_AUTH_MOCK_LOGIN:-0}" = "0" ]; then
    echo "✓ Logged in to github.com as test-user"
    exit 0
  else
    echo "Authentication failed"
    exit 1
  fi
else
  echo "Unexpected gh command: $*"
  exit 1
fi
EOF
  chmod +x "${TEST_TEMP_DIR}/bin/gh"
}

teardown() {
  teardown_test_environment
}

@test "gh auth skips when already authenticated" {
  export GH_AUTH_MOCK_STATUS=0
  
  run "${TEST_ROOT}/scripts/gh_auth.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] GitHub authentication already configured.'* ]]
  [[ "${output}" != *'DRY-RUN'* ]]
}

@test "gh auth warns in non-interactive mode when not authenticated" {
  export GH_AUTH_MOCK_STATUS=1
  export ONBOARD_NON_INTERACTIVE=1
  
  run "${TEST_ROOT}/scripts/gh_auth.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[WARN] GitHub authentication required but running in non-interactive mode.'* ]]
  [[ "${output}" == *'[WARN] Please run: gh auth login --web --git-protocol https'* ]]
}

@test "gh auth performs login in dry-run mode" {
  export GH_AUTH_MOCK_STATUS=1
  export GH_AUTH_MOCK_LOGIN=0
  export ONBOARD_DRY_RUN=1
  export ONBOARD_NON_INTERACTIVE=0
  
  run "${TEST_ROOT}/scripts/gh_auth.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] DRY-RUN: Authenticate with GitHub: gh auth login --web --git-protocol https'* ]]
}

@test "gh auth handles login failure" {
  export GH_AUTH_MOCK_STATUS=1
  export GH_AUTH_MOCK_LOGIN=1
  export ONBOARD_DRY_RUN=0
  export ONBOARD_NON_INTERACTIVE=0
  
  run "${TEST_ROOT}/scripts/gh_auth.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[ERROR] GitHub authentication failed.'* ]]
}

@test "gh auth provides troubleshooting guidance on failure" {
  export GH_AUTH_MOCK_STATUS=1
  export GH_AUTH_MOCK_LOGIN=1
  export ONBOARD_DRY_RUN=0
  export ONBOARD_NON_INTERACTIVE=0
  
  run "${TEST_ROOT}/scripts/gh_auth.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[ERROR] GitHub authentication failed.'* ]]
  [[ "${output}" == *'Check your internet connection'* ]]
  [[ "${output}" == *'Ensure your browser is accessible'* ]]
  [[ "${output}" == *'Retry with: gh auth login --web --git-protocol https'* ]]
}
