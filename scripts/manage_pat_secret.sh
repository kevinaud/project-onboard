#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=./utils.sh
. "${REPO_ROOT}/scripts/utils.sh"
# shellcheck source=./detect.sh
. "${REPO_ROOT}/scripts/detect.sh"

print_usage() {
  cat <<'USAGE'
Usage: manage_pat_secret.sh [options]

Set the GitHub Actions secret used by the Windows E2E workflow.

Options:
  --secret-name <name>    Secret name to update (default: PROJECT_ONBOARD_PAT)
  --repo <owner/name>     Target repository slug (default: current repo)
  --token-value <value>   PAT value to store (mutually exclusive with --token-file)
  --token-file <path>     Read PAT value from a file (mutually exclusive with --token-value)
  --dry-run               Show planned actions without making changes
  --help                  Show this help message

Notes:
  * The GitHub CLI must already be authenticated (`gh auth login`).
  * Provide a classic PAT with the `repo` scope.
  * Secrets are stored for the Actions app to make them available to workflows.
USAGE
}

SECRET_NAME="PROJECT_ONBOARD_PAT"
TARGET_REPO=""
TOKEN_VALUE=""
TOKEN_FILE=""
DRY_RUN=0

while (($# > 0)); do
  case "$1" in
    --secret-name)
      SECRET_NAME="${2:-}"
      if [ -z "${SECRET_NAME}" ]; then
        log_error "--secret-name requires a value"
        exit 1
      fi
      shift 2
      ;;
    --repo)
      TARGET_REPO="${2:-}"
      if [ -z "${TARGET_REPO}" ]; then
        log_error "--repo requires a value"
        exit 1
      fi
      shift 2
      ;;
    --token-value)
      TOKEN_VALUE="${2:-}"
      if [ -z "${TOKEN_VALUE}" ]; then
        log_error "--token-value requires a value"
        exit 1
      fi
      shift 2
      ;;
    --token-file)
      TOKEN_FILE="${2:-}"
      if [ -z "${TOKEN_FILE}" ]; then
        log_error "--token-file requires a value"
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

ensure_environment_loaded() {
  if [ -z "${ONBOARD_OS:-}" ] || [ -z "${ONBOARD_ARCH:-}" ]; then
    load_environment_facts
  fi
}

ensure_environment_loaded

if ! command -v gh >/dev/null 2>&1; then
  log_error "GitHub CLI (gh) is required but not found on PATH."
  exit 1
fi

if [ -n "${TOKEN_VALUE}" ] && [ -n "${TOKEN_FILE}" ]; then
  log_error "--token-value and --token-file cannot be used together."
  exit 1
fi

if [ -n "${TOKEN_FILE}" ]; then
  if [ ! -f "${TOKEN_FILE}" ]; then
    log_error "Token file does not exist: ${TOKEN_FILE}"
    exit 1
  fi
  TOKEN_VALUE=$(cat "${TOKEN_FILE}")
fi

if [ -z "${TOKEN_VALUE}" ]; then
  log_error "A PAT must be provided via --token-value or --token-file."
  exit 1
fi

# Trim carriage returns and trailing newlines to avoid storing malformed secrets.
TOKEN_VALUE=$(printf '%s' "${TOKEN_VALUE}" | tr -d '\r')
while [ "${TOKEN_VALUE%$'\n'}" != "${TOKEN_VALUE}" ]; do
  TOKEN_VALUE=${TOKEN_VALUE%$'\n'}
done

if [ -z "${TOKEN_VALUE}" ]; then
  log_error "Provided token is empty after trimming."
  exit 1
fi

if [ -z "${TARGET_REPO}" ]; then
  if ! TARGET_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
    log_error "Failed to determine repository slug. Use --repo owner/name."
    exit 1
  fi
fi

log_info "Using repository: ${TARGET_REPO}"
log_info "Secret name: ${SECRET_NAME}"

if ! gh auth status >/dev/null 2>&1; then
  log_error "GitHub CLI is not authenticated. Run 'gh auth login' first."
  exit 1
fi

if [ ${DRY_RUN} -eq 1 ]; then
  log_info "[dry-run] Would set secret ${SECRET_NAME} for repository ${TARGET_REPO}"
  exit 0
fi

log_info "Updating ${SECRET_NAME} secret for repository ${TARGET_REPO}..."

if gh secret set --help 2>&1 | grep -q -- '--body-file'; then
  TEMP_FILE=$(mktemp)
  cleanup() {
    rm -f "${TEMP_FILE}"
  }
  trap cleanup EXIT

  printf '%s' "${TOKEN_VALUE}" >"${TEMP_FILE}"

  if ! gh secret set "${SECRET_NAME}" --app actions --repo "${TARGET_REPO}" --body-file "${TEMP_FILE}"; then
    log_error "Failed to update secret ${SECRET_NAME}."
    exit 1
  fi

  cleanup
  trap - EXIT
  unset TEMP_FILE
else
  if ! printf '%s' "${TOKEN_VALUE}" | gh secret set "${SECRET_NAME}" --app actions --repo "${TARGET_REPO}"; then
    log_error "Failed to update secret ${SECRET_NAME}."
    exit 1
  fi
fi

unset TOKEN_VALUE
log_info "Secret ${SECRET_NAME} updated successfully."
