#!/usr/bin/env bash
# shellcheck shell=bash

# Logging helpers shared across onboarding scripts. Intentionally minimal for iteration 0.
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
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    printf '[VERBOSE] %s\n' "$*"
  fi
}

announce_plan() {
  printf '\nPlan:\n'
  for step in "$@"; do
    printf '  - %s\n' "$step"
  done
  printf '\n'
}
