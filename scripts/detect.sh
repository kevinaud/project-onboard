#!/usr/bin/env bash
# shellcheck shell=bash

# Provide a lightweight environment snapshot for planning output.
detect_environment() {
  local kernel arch is_wsl devcontainer

  kernel="$(uname -s 2>/dev/null || echo unknown)"
  arch="$(uname -m 2>/dev/null || echo unknown)"

  if grep -qi microsoft /proc/version 2>/dev/null; then
    is_wsl=true
  else
    is_wsl=false
  fi

  if [[ -n "${DEVCONTAINER:-}" || -n "${REMOTE_CONTAINERS_IP:-}" ]]; then
    devcontainer=true
  else
    devcontainer=false
  fi

  printf '{"os":"%s","arch":"%s","is_wsl":%s,"in_devcontainer":%s}\n' \
    "$kernel" \
    "$arch" \
    "$is_wsl" \
    "$devcontainer"
}
