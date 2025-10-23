#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export TEST_ROOT
export REPO_ROOT="${TEST_ROOT}"

load_utils() {
  # shellcheck source=../scripts/utils.sh
  . "${TEST_ROOT}/scripts/utils.sh"
}

load_detect() {
  # shellcheck source=../scripts/detect.sh
  . "${TEST_ROOT}/scripts/detect.sh"
}

setup_test_environment() {
  export ONBOARD_DRY_RUN=1
  export ONBOARD_NON_INTERACTIVE=1
  export ONBOARD_VERBOSE=0
  export ONBOARD_NO_OPTIONAL=0
  
  # Create isolated temp directory for each test
  export TEST_TEMP_DIR=$(mktemp -d)
  export HOME="${TEST_TEMP_DIR}/home"
  mkdir -p "${HOME}"
  
  load_utils
}

teardown_test_environment() {
  if [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "${TEST_TEMP_DIR}" ]; then
    rm -rf "${TEST_TEMP_DIR}"
  fi
}
