#!/usr/bin/env bash
# scripts/docker_verify_wsl.sh
# Verifies Docker Desktop integration from within WSL.
# This script is called from setup.sh after cloning the project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh"

verify_docker() {
    log_info "Verifying Docker Desktop integration with WSL..."

    # Check if docker command is available
    if ! command -v docker &>/dev/null; then
        log_error "Docker command not found in WSL."
        show_docker_remediation
        return 1
    fi

    # Check docker version
    if ! docker --version &>/dev/null; then
        log_error "Docker version check failed."
        show_docker_remediation
        return 1
    fi

    log_info "Docker version: $(docker --version)"

    # Test docker functionality with hello-world
    log_info "Testing Docker with hello-world container..."
    if ! docker run --rm hello-world &>/dev/null; then
        log_error "Docker hello-world test failed."
        show_docker_remediation
        return 1
    fi

    log_info "Docker Desktop integration verified successfully."
    return 0
}

show_docker_remediation() {
    log_warn ""
    log_warn "========================================"
    log_warn "Docker Desktop Integration Issue"
    log_warn "========================================"
    log_warn "Docker verification failed. Please ensure:"
    log_warn "  1. Docker Desktop is running on Windows."
    log_warn "  2. In Docker Desktop Settings > Resources > WSL Integration,"
    log_warn "     'Ubuntu-22.04' (or your WSL distribution) is enabled."
    log_warn "  3. You have clicked 'Apply & Restart' in Docker Desktop."
    log_warn "  4. After making changes, restart your WSL terminal."
    log_warn "========================================"
    log_warn ""
    log_warn "Once you have completed these steps, you can re-run this verification:"
    log_warn "  bash $SCRIPT_DIR/docker_verify_wsl.sh"
    log_warn ""
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    verify_docker
fi
