#!/usr/bin/env bash

# shellcheck shell=bash
# Platform detection helpers.
set -euo pipefail

_detect_kernel_name() {
  uname -s 2>/dev/null || printf 'Unknown'
}

_detect_machine_arch() {
  uname -m 2>/dev/null || printf 'unknown'
}

is_wsl() {
  if [ -n "${WSL_INTEROP:-}" ] || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    return 0
  fi

  if [ -f /proc/sys/kernel/osrelease ] && grep -qi 'microsoft' /proc/sys/kernel/osrelease; then
    return 0
  fi

  if [ -f /proc/version ] && grep -qi 'microsoft' /proc/version; then
    return 0
  fi

  return 1
}

_detect_os() {
  local kernel
  kernel=$(_detect_kernel_name)
  case "$kernel" in
    Darwin)
      printf 'macos'
      ;;
    Linux)
      if is_wsl; then
        printf 'wsl'
      else
        printf 'linux'
      fi
      ;;
    MINGW*|MSYS*)
      printf 'windows'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

_detect_shell_name() {
  if [ -n "${SHELL:-}" ]; then
    basename "$SHELL" 2>/dev/null && return 0
  fi

  if command -v ps >/dev/null 2>&1; then
    ps -p "$$" -o comm= 2>/dev/null && return 0
  fi

  printf 'unknown'
}

_brew_prefix_for() {
  local os="$1"
  local arch="$2"

  if [ "$os" != 'macos' ]; then
    printf ''
    return 0
  fi

  case "$arch" in
    arm64)
      printf '/opt/homebrew'
      ;;
    *)
      printf '/usr/local'
      ;;
  esac
}

_json_escape() {
  # Minimal JSON escaper for simple strings.
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

_detect_bool() {
  if [ "$1" = 'true' ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

detect_environment() {
  local os arch shell_name brew_prefix wsl_flag

  os=$(_detect_os)
  arch=$(_detect_machine_arch)
  shell_name=$(_detect_shell_name)

  if is_wsl; then
    wsl_flag=true
  else
    wsl_flag=false
  fi

  brew_prefix=$(_brew_prefix_for "$os" "$arch")

  if [ -n "$brew_prefix" ]; then
    brew_prefix=$(printf '"%s"' "$(_json_escape "$brew_prefix")")
  else
    brew_prefix='null'
  fi

  printf '{"os":"%s","arch":"%s","is_wsl":%s,"shell":"%s","brew_prefix":%s}\n' \
    "$(_json_escape "$os")" \
    "$(_json_escape "$arch")" \
    "$(_detect_bool "$wsl_flag")" \
    "$(_json_escape "$shell_name")" \
    "$brew_prefix"
}

load_environment_facts() {
  ONBOARD_OS=$(_detect_os)
  ONBOARD_ARCH=$(_detect_machine_arch)
  if is_wsl; then
    ONBOARD_IS_WSL=1
  else
    ONBOARD_IS_WSL=0
  fi
  ONBOARD_SHELL_NAME=$(_detect_shell_name)
  ONBOARD_BREW_PREFIX=$(_brew_prefix_for "$ONBOARD_OS" "$ONBOARD_ARCH")

  export ONBOARD_OS ONBOARD_ARCH ONBOARD_IS_WSL ONBOARD_SHELL_NAME ONBOARD_BREW_PREFIX
}
