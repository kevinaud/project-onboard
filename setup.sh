#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/utils.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/detect.sh"

VERBOSE=false
DRY_RUN=false
NON_INTERACTIVE=false
NO_OPTIONAL=false
PROJECT_ONBOARD_WORKSPACE_DEFAULT="${PROJECT_ONBOARD_WORKSPACE:-}" # optional env override
if [[ -n "$PROJECT_ONBOARD_WORKSPACE_DEFAULT" ]]; then
  WORKSPACE="$PROJECT_ONBOARD_WORKSPACE_DEFAULT"
else
  WORKSPACE="$HOME/projects"
fi

print_usage() {
  cat <<'USAGE'
Usage: ./setup.sh [flags]

Flags:
  --non-interactive   Disable interactive prompts (planned).
  --no-optional       Skip optional extras (reserved).
  --dry-run           Do not perform any host changes.
  --verbose           Increase logging detail.
  --workspace <path>  Override the target workspace directory.
  -h, --help          Show this help message.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      NON_INTERACTIVE=true
      ;;
    --no-optional)
      NO_OPTIONAL=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    --workspace)
      if [[ $# -lt 2 ]]; then
        log_error "Missing value for --workspace"
        exit 1
      fi
      WORKSPACE="$2"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
  shift
done

log_verbose "Verbose logging enabled"

if [[ "$DRY_RUN" == "false" ]]; then
  log_warn "Iteration 0 treats all runs as dry runs. No changes will be made."
  DRY_RUN=true
fi

env_snapshot="$(detect_environment)"

log_info "project-onboard iteration 0 scaffold"
log_info "Flags: dry_run=$DRY_RUN, non_interactive=$NON_INTERACTIVE, no_optional=$NO_OPTIONAL, verbose=$VERBOSE"
log_info "Workspace: $WORKSPACE"
log_verbose "Environment snapshot: $env_snapshot"

announce_plan \
  "Capture environment details for future iterations" \
  "Respect workspace override: $WORKSPACE" \
  "Skip optional installs until later iterations" \
  "Exit after printing this plan"

log_info "Nothing to do yet. Follow upcoming iterations for real actions."
