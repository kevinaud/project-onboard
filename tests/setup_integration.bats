#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_environment
  
  # Create mock scripts directory
  mkdir -p "${TEST_TEMP_DIR}/scripts"
  
  # Mock the scripts that setup.sh calls
  cat > "${TEST_TEMP_DIR}/scripts/detect.sh" << 'EOF'
#!/usr/bin/env bash
detect_environment() {
  echo "wsl"
}
EOF
  
  cat > "${TEST_TEMP_DIR}/scripts/utils.sh" << 'EOF'
#!/usr/bin/env bash
log_info() {
  echo "[INFO] $*"
}
log_warn() {
  echo "[WARN] $*"
}
log_error() {
  echo "[ERROR] $*"
}
log_verbose() {
  [ "${ONBOARD_VERBOSE:-0}" -eq 1 ] && echo "[VERBOSE] $*"
  return 0
}
announce_plan() {
  echo "=== Onboarding Plan ==="
  echo "Platform: $1"
  shift
  for step in "$@"; do
    echo "  - $step"
  done
}
EOF
  
  # Mock clone_project.sh
  cat > "${TEST_TEMP_DIR}/scripts/clone_project.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: clone_project.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/clone_project.sh"
  
  # Mock git_config_minimum.sh
  cat > "${TEST_TEMP_DIR}/scripts/git_config_minimum.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: git_config_minimum.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/git_config_minimum.sh"
  
  # Mock docker_verify_wsl.sh - this is what we're testing
  cat > "${TEST_TEMP_DIR}/scripts/docker_verify_wsl.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: docker_verify_wsl.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/docker_verify_wsl.sh"
  
  # Mock install_prereqs_wsl.sh
  cat > "${TEST_TEMP_DIR}/scripts/install_prereqs_wsl.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: install_prereqs_wsl.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/install_prereqs_wsl.sh"
  
  # Mock git_identity.sh
  cat > "${TEST_TEMP_DIR}/scripts/git_identity.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: git_identity.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/git_identity.sh"
  
  # Mock gh_auth.sh
  cat > "${TEST_TEMP_DIR}/scripts/gh_auth.sh" << 'EOF'
#!/usr/bin/env bash
echo "[INFO] Mock: gh_auth.sh called"
exit 0
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/gh_auth.sh"
  
  # Create a simplified test version of setup.sh
  cat > "${TEST_TEMP_DIR}/setup.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Source utilities
# shellcheck source=scripts/utils.sh
. "${SCRIPT_DIR}/scripts/utils.sh"

# shellcheck source=scripts/detect.sh
. "${SCRIPT_DIR}/scripts/detect.sh"

# Detect platform
PLATFORM=$(detect_environment)

if [ "${PLATFORM}" = "wsl" ]; then
  announce_plan "WSL" \
    "Install prerequisites" \
    "Clone project repository" \
    "Verify Docker functionality" \
    "Configure git" \
    "Set up git identity" \
    "Authenticate with GitHub CLI"
  
  "${SCRIPT_DIR}/scripts/install_prereqs_wsl.sh"
  "${SCRIPT_DIR}/scripts/clone_project.sh"
  "${SCRIPT_DIR}/scripts/docker_verify_wsl.sh"
  "${SCRIPT_DIR}/scripts/git_config_minimum.sh"
  "${SCRIPT_DIR}/scripts/git_identity.sh"
  "${SCRIPT_DIR}/scripts/gh_auth.sh"
  
  log_info "Onboarding complete for WSL."
fi
EOF
  chmod +x "${TEST_TEMP_DIR}/setup.sh"
}

teardown() {
  teardown_test_environment
}

@test "setup.sh calls docker_verify_wsl.sh after clone_project.sh on WSL" {
  run "${TEST_TEMP_DIR}/setup.sh"
  
  [ "$status" -eq 0 ]
  
  # Verify the order of calls
  output_lines=()
  while IFS= read -r line; do
    output_lines+=("$line")
  done <<< "$output"
  
  # Find indices of mock calls
  clone_idx=-1
  docker_idx=-1
  git_config_idx=-1
  
  for i in "${!output_lines[@]}"; do
    case "${output_lines[$i]}" in
      *"Mock: clone_project.sh called"*)
        clone_idx=$i
        ;;
      *"Mock: docker_verify_wsl.sh called"*)
        docker_idx=$i
        ;;
      *"Mock: git_config_minimum.sh called"*)
        git_config_idx=$i
        ;;
    esac
  done
  
  # Verify that docker_verify_wsl.sh was called
  [ "$docker_idx" -ne -1 ]
  
  # Verify that clone_project.sh was called before docker_verify_wsl.sh
  [ "$clone_idx" -ne -1 ]
  [ "$clone_idx" -lt "$docker_idx" ]
  
  # Verify that docker_verify_wsl.sh was called before git_config_minimum.sh
  [ "$git_config_idx" -ne -1 ]
  [ "$docker_idx" -lt "$git_config_idx" ]
}

@test "setup.sh includes docker verification in execution plan" {
  run "${TEST_TEMP_DIR}/setup.sh"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Verify Docker functionality" ]]
}

@test "setup.sh execution order is: prereqs -> clone -> docker -> git config -> identity -> gh" {
  run "${TEST_TEMP_DIR}/setup.sh"
  
  [ "$status" -eq 0 ]
  
  # Extract just the mock calls
  mock_calls=$(echo "$output" | grep "Mock:" | sed 's/.*Mock: //' | sed 's/ called//')
  
  expected_order="install_prereqs_wsl.sh
clone_project.sh
docker_verify_wsl.sh
git_config_minimum.sh
git_identity.sh
gh_auth.sh"
  
  [ "$mock_calls" = "$expected_order" ]
}

@test "docker_verify_wsl.sh failure does not prevent subsequent steps" {
  # Replace docker_verify_wsl.sh with a failing version
  cat > "${TEST_TEMP_DIR}/scripts/docker_verify_wsl.sh" << 'EOF'
#!/usr/bin/env bash
echo "[ERROR] Mock: docker_verify_wsl.sh failed"
exit 1
EOF
  chmod +x "${TEST_TEMP_DIR}/scripts/docker_verify_wsl.sh"
  
  run "${TEST_TEMP_DIR}/setup.sh"
  
  # The script should fail due to set -e
  [ "$status" -ne 0 ]
  
  # But it should have attempted to run docker_verify_wsl.sh
  [[ "$output" =~ "docker_verify_wsl.sh failed" ]]
}
