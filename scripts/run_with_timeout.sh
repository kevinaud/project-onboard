#!/usr/bin/env bash
# scripts/run_with_timeout.sh
# Executes a command with a configurable timeout to prevent long-running hangs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/utils.sh"

usage() {
  cat <<'EOF'
Usage: run_with_timeout.sh [timeout_seconds] -- <command> [args...]
       run_with_timeout.sh <command> [args...]

Runs the provided command with a timeout (default 300 seconds).
Specify a custom timeout as the first argument or rely on the default.
EOF
}

DEFAULT_TIMEOUT="${ONBOARD_DEFAULT_TIMEOUT:-300}"
TIMEOUT_VALUE=""
COMMAND=("")

if [ "$#" -eq 0 ]; then
  usage
  exit 64
fi

if [[ "$1" =~ ^[0-9]+$ ]]; then
  TIMEOUT_VALUE="$1"
  shift
else
  TIMEOUT_VALUE="${DEFAULT_TIMEOUT}"
fi

if [ "$#" -gt 0 ] && [ "$1" = "--" ]; then
  shift
fi

if [ "$#" -eq 0 ]; then
  log_error 'No command provided to run_with_timeout.sh'
  usage
  exit 64
fi

COMMAND=("$@")

# Prefer GNU timeout, fallback to gtimeout (Homebrew coreutils on macOS).
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
fi

if [ -z "${TIMEOUT_CMD}" ]; then
  log_warn 'timeout command not found; running without timeout enforcement.'
  "${COMMAND[@]}"
  exit $?
fi

log_info "Running with timeout ${TIMEOUT_VALUE}s: ${COMMAND[*]}"

set +e
"${TIMEOUT_CMD}" "${TIMEOUT_VALUE}" "${COMMAND[@]}"
status=$?
set -e

if [ ${status} -eq 0 ]; then
  exit 0
fi

if [ ${status} -eq 124 ]; then
  log_error "Command timed out after ${TIMEOUT_VALUE}s: ${COMMAND[*]}"
fi

exit ${status}
