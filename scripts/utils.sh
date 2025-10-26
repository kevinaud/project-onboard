#!/usr/bin/env bash

# shellcheck shell=bash
# Utility helpers shared across onboarding scripts.
set -euo pipefail

# Keep IFS narrow to avoid surprising word-splitting.
IFS=$' \t\n'

# Allow host wrapper to pass branch override via environment.
if [ -z "${ONBOARD_BRANCH:-}" ] && [ -n "${PROJECT_ONBOARD_BRANCH:-}" ]; then
  ONBOARD_BRANCH="${PROJECT_ONBOARD_BRANCH}"
fi

# Default flag values; downstream scripts may override via env or CLI flags.
: "${ONBOARD_VERBOSE:=0}"
: "${ONBOARD_NON_INTERACTIVE:=0}"
: "${ONBOARD_DRY_RUN:=0}"
: "${ONBOARD_NO_OPTIONAL:=0}"
: "${ONBOARD_BRANCH:=main}"
: "${ONBOARD_WORKSPACE_DIR:=${HOME}/projects}"

# Normalise ONBOARD_DRY_RUN to a strict 0/1 so downstream checks stay simple.
case "${ONBOARD_DRY_RUN}" in
  1|true|TRUE|True|yes|YES|Yes)
    ONBOARD_DRY_RUN=1
    ;;
  *)
    ONBOARD_DRY_RUN=0
    ;;
esac

export ONBOARD_VERBOSE ONBOARD_NON_INTERACTIVE ONBOARD_DRY_RUN ONBOARD_NO_OPTIONAL ONBOARD_BRANCH ONBOARD_WORKSPACE_DIR
export PROJECT_ONBOARD_BRANCH="${ONBOARD_BRANCH}"

# Timestamp helper shared by backup path generator and logging.
_now_timestamp() {
  date '+%Y%m%d-%H%M%S'
}

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

log_verbose() {
  if [ "${ONBOARD_VERBOSE}" = "1" ]; then
    printf '[VERBOSE] %s\n' "$*"
  fi
}

announce_plan() {
  if [ "$#" -eq 0 ]; then
    log_warn 'announce_plan invoked with no steps'
    return 0
  fi

  log_info 'Execution plan:'
  for step in "$@"; do
    printf '  - %s\n' "$step"
  done
}

confirm() {
  if [ "$#" -lt 1 ]; then
    log_error 'confirm requires at least a prompt message'
    return 1
  fi

  local prompt="$1"
  local default_response="${2:-yes}" # yes|no
  local response

  case "${default_response}" in
    yes) response_default='Y/n' ; default_value=0 ;;
    no)  response_default='y/N' ; default_value=1 ;;
    *)
      log_error "Invalid default response for confirm: ${default_response}"
      return 1
      ;;
  esac

  if [ "${ONBOARD_NON_INTERACTIVE}" = "1" ]; then
    log_verbose "Non-interactive mode enabled; defaulting to ${default_response} for: ${prompt}"
    return "${default_value}"
  fi

  while true; do
    printf '%s [%s]: ' "$prompt" "$response_default"
    if ! IFS= read -r response; then
      log_warn 'Input aborted; assuming default answer'
      return "${default_value}"
    fi

    if [ -z "$response" ]; then
      return "${default_value}"
    fi

    case "$response" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *)
        printf 'Please answer yes or no.\n'
        ;;
    esac
  done
}

prompt_for_input() {
  if [ "$#" -lt 1 ]; then
    log_error 'prompt_for_input requires at least a prompt message'
    return 1
  fi

  local prompt="$1"
  local default_value="${2:-}"

  if [ "${ONBOARD_NON_INTERACTIVE}" = "1" ]; then
    log_verbose "Non-interactive mode; returning default for prompt: ${prompt}"
    printf '%s\n' "${default_value}"
    return 0
  fi

  if [ -n "${default_value}" ]; then
    printf '%s [%s]: ' "${prompt}" "${default_value}" >&2
  else
    printf '%s: ' "${prompt}" >&2
  fi

  local response
  if ! IFS= read -r response; then
    log_warn 'Input aborted; falling back to default value'
    response="${default_value}"
  fi

  if [ -z "${response}" ]; then
    response="${default_value}"
  fi

  printf '%s\n' "${response}"
}

generate_backup_path() {
  if [ "$#" -ne 1 ]; then
    log_error 'generate_backup_path requires exactly one argument (the original path)'
    return 1
  fi

  local target="$1"
  local timestamp
  timestamp=$(_now_timestamp)

  printf '%s.bak.%s\n' "$target" "$timestamp"
}

run_cmd() {
  if [ "$#" -lt 2 ]; then
    log_error 'run_cmd requires a description and at least one command argument'
    return 1
  fi

  local description="$1"
  shift

  if [ "${ONBOARD_DRY_RUN}" = "1" ]; then
    log_info "DRY-RUN: ${description}: $*"
    return 0
  fi

  log_info "$description"
  log_verbose "Executing: $*"
  "$@"
}
