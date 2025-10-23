#!/usr/bin/env bats

load test_helper

setup() {
  setup_test_environment
  
  # Mock git binary
  export PATH="${TEST_TEMP_DIR}/bin:${PATH}"
  mkdir -p "${TEST_TEMP_DIR}/bin"
  
  # Default mock: successful operations
  cat > "${TEST_TEMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "clone" ]; then
  if [ "${GIT_CLONE_MOCK_FAIL:-0}" = "1" ]; then
    echo "fatal: repository not found"
    exit 128
  fi
  mkdir -p "$3/.git"
  echo "Cloning into '$3'..."
  exit 0
elif [ "$1" = "fetch" ]; then
  if [ "${GIT_FETCH_MOCK_FAIL:-0}" = "1" ]; then
    echo "fatal: fetch failed"
    exit 1
  fi
  echo "Fetching..."
  exit 0
elif [ "$1" = "pull" ]; then
  if [ "${GIT_PULL_MOCK_FAIL:-0}" = "1" ]; then
    echo "fatal: pull failed"
    exit 1
  fi
  echo "Updating..."
  exit 0
else
  echo "Unexpected git command: $*"
  exit 1
fi
EOF
  chmod +x "${TEST_TEMP_DIR}/bin/git"
  
  # Set default workspace
  export ONBOARD_WORKSPACE_DIR="${TEST_TEMP_DIR}/workspace"
  mkdir -p "${ONBOARD_WORKSPACE_DIR}"
}

teardown() {
  teardown_test_environment
}

@test "clone_project clones repo when directory does not exist" {
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"[INFO] DRY-RUN: Clone private repository: git clone https://github.com/psps-mental-health-app/mental-health-app-frontend.git ${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"* ]]
  [[ "${output}" == *'[INFO] Next steps:'* ]]
  [[ "${output}" == *"code ${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"* ]]
}

@test "clone_project updates existing git repository" {
  local repo_path="${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"
  mkdir -p "${repo_path}/.git"
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"[INFO] Project directory already exists. Fetching latest changes..."* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Fetch latest changes: git fetch --all --prune'* ]]
  [[ "${output}" == *'[INFO] DRY-RUN: Pull latest changes: git pull --ff-only'* ]]
}

@test "clone_project warns on non-git directory conflict in non-interactive mode" {
  local repo_path="${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"
  mkdir -p "${repo_path}/some-file"
  echo "content" > "${repo_path}/some-file/test.txt"
  
  export ONBOARD_NON_INTERACTIVE=1
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"[WARN] Directory exists at ${repo_path} but is not a Git repository."* ]]
  [[ "${output}" == *'[WARN] Skipping clone. Please move or remove this directory and re-run.'* ]]
}

@test "clone_project respects custom workspace via ONBOARD_WORKSPACE_DIR" {
  export ONBOARD_WORKSPACE_DIR="${TEST_TEMP_DIR}/custom-workspace"
  mkdir -p "${ONBOARD_WORKSPACE_DIR}"
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *"${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"* ]]
}

@test "clone_project handles git clone failure gracefully" {
  export GIT_CLONE_MOCK_FAIL=1
  export ONBOARD_DRY_RUN=0
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[ERROR] Failed to clone repository.'* ]]
  [[ "${output}" == *'Check your GitHub authentication'* ]]
  [[ "${output}" == *'Verify you have access to the repository'* ]]
}

@test "clone_project handles git fetch failure gracefully" {
  local repo_path="${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"
  mkdir -p "${repo_path}/.git"
  export GIT_FETCH_MOCK_FAIL=1
  export ONBOARD_DRY_RUN=0
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[ERROR] Failed to fetch updates.'* ]]
}

@test "clone_project handles git pull failure gracefully" {
  local repo_path="${ONBOARD_WORKSPACE_DIR}/mental-health-app-frontend"
  mkdir -p "${repo_path}/.git"
  export GIT_PULL_MOCK_FAIL=1
  export ONBOARD_DRY_RUN=0
  
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 1 ]
  [[ "${output}" == *'[ERROR] Failed to pull updates.'* ]]
}

@test "clone_project provides next steps after successful clone" {
  run "${TEST_ROOT}/scripts/clone_project.sh"
  [ "$status" -eq 0 ]
  [[ "${output}" == *'[INFO] Next steps:'* ]]
  [[ "${output}" == *'1. Open the project:'* ]]
  [[ "${output}" == *'2. Reopen in Container'* ]]
}
