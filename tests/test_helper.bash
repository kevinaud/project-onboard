#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export TEST_ROOT

load_utils() {
  # shellcheck source=../scripts/utils.sh
  . "${TEST_ROOT}/scripts/utils.sh"
}

load_detect() {
  # shellcheck source=../scripts/detect.sh
  . "${TEST_ROOT}/scripts/detect.sh"
}
