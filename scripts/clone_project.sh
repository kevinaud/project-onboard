#!/usr/bin/env bash

set -euo pipefail
IFS=$' \t\n'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

# shellcheck source=scripts/utils.sh
. "${REPO_ROOT}/scripts/utils.sh"

# Private repository URL
readonly PROJECT_REPO_URL="https://github.com/psps-mental-health-app/mental-health-app-frontend.git"
readonly PROJECT_REPO_NAME="mental-health-app-frontend"

# Determine workspace directory
get_workspace_dir() {
  local workspace="${ONBOARD_WORKSPACE_DIR:-}"
  
  if [ -z "${workspace}" ]; then
    workspace="${HOME}/projects"
  fi
  
  echo "${workspace}"
}

# Clone or update the private project repository
clone_or_update_project() {
  local workspace_dir
  workspace_dir=$(get_workspace_dir)
  
  local target_repo_path="${workspace_dir}/${PROJECT_REPO_NAME}"
  
  log_info "Workspace directory: ${workspace_dir}"
  
  # Create workspace directory if it doesn't exist
  if [ ! -d "${workspace_dir}" ]; then
    log_info "Creating workspace directory: ${workspace_dir}"
    if ! run_cmd 'Create workspace directory' mkdir -p "${workspace_dir}"; then
      log_error "Failed to create workspace directory: ${workspace_dir}"
      return 1
    fi
  fi
  
  # Check if target directory exists
  if [ ! -d "${target_repo_path}" ]; then
    # Directory doesn't exist, clone the repository
    log_info "Cloning ${PROJECT_REPO_NAME} to ${target_repo_path}..."
    
    if ! run_cmd 'Clone private repository' git clone "${PROJECT_REPO_URL}" "${target_repo_path}"; then
      log_error "Failed to clone repository."
      log_error "Troubleshooting steps:"
      log_error "  - Check your GitHub authentication (run: gh auth status)"
      log_error "  - Verify you have access to the repository"
      log_error "  - Ensure your internet connection is stable"
      return 1
    fi
    log_info "Repository cloned successfully to ${target_repo_path}"
  elif [ -d "${target_repo_path}/.git" ]; then
    # Directory exists and is a git repository, update it
    log_info "Project directory already exists. Fetching latest changes..."
    
    (
      cd "${target_repo_path}" || {
        log_error "Failed to change to repository directory"
        return 1
      }
      
      if ! run_cmd 'Fetch latest changes' git fetch --all --prune; then
        log_error "Failed to fetch updates."
        return 1
      fi
      
      if ! run_cmd 'Pull latest changes' git pull --ff-only; then
        log_error "Failed to pull updates."
        log_error "You may have uncommitted changes or merge conflicts."
        log_error "Navigate to the repository and resolve manually."
        return 1
      fi
      
      log_info "Repository updated successfully."
    )
  else
    # Directory exists but is not a git repository
    if [ "${ONBOARD_NON_INTERACTIVE}" = "1" ]; then
      log_warn "Directory exists at ${target_repo_path} but is not a Git repository."
      log_warn "Skipping clone. Please move or remove this directory and re-run."
      return 1
    else
      log_warn "A directory exists at ${target_repo_path} but it's not a Git repository."
      log_warn "Please move or remove it and re-run this script."
      
      if ! confirm "Would you like to skip cloning for now?"; then
        log_error "Cannot proceed with cloning. Please resolve the directory conflict."
        return 1
      fi
      
      log_info "Skipping clone as requested."
      return 0
    fi
  fi
  
  log_info "Next steps:"
  log_info "  1. Open the project: code ${target_repo_path}"
  log_info "  2. Reopen in Container when prompted by VS Code"
}

# Main execution
clone_or_update_project
