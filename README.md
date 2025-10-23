# Project Onboard

Cross-platform onboarding tooling for the mental-health-app-frontend project. This repository provides automated setup for macOS and WSL (Ubuntu) environments, including prerequisite installation, GitHub authentication, and private repository cloning.

## Quick Start

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash
```

### Windows (WSL)

From PowerShell (full wrapper coming in later iterations):

```powershell
.\setup.ps1
```

Then inside WSL/Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash
```

## Usage

```bash
./setup.sh [options]
```

Available options:

- `--dry-run` (default): Print planned actions only, no host changes.
- `--non-interactive`: Assume default answers to prompts.
- `--no-optional`: Skip optional features.
- `--verbose`: Emit verbose diagnostics.
- `--workspace <path>`: Override the default workspace directory (default: `~/projects`).
- `--help`: Show help message.

> **Note**
> Dry-run mode is currently enforced during early iterations. No host changes are performed yet.

## What It Does

Iteration 3 completes the macOS onboarding flow:

1. **Platform Detection**: Identifies macOS (Intel/Apple Silicon) or WSL (Ubuntu).
2. **Prerequisites**: Installs Homebrew, Git, GitHub CLI, and chezmoi as needed.
3. **Git Identity**: Prompts for `user.name` and `user.email` if not already configured.
4. **Git Config**: Applies minimal project-required `.gitconfig` with safe backup.
5. **GitHub Auth**: 
   - **macOS**: Runs `gh auth login --web` (browser-based).
   - **WSL**: Skips (uses Windows Git Credential Manager configured in later iterations).
6. **Clone Repository**: Clones the private `mental-health-app-frontend` repository to `~/projects` (or specified workspace).

## Next Steps

After setup completes:

```bash
code ~/projects/mental-health-app-frontend
```

Then **Reopen in Container** when prompted by VS Code to use the Dev Container environment.

## Testing

Run unit tests from the repository root:

```bash
bats tests/
```

Lint scripts with ShellCheck:

```bash
shellcheck -x setup.sh scripts/*.sh
```

## Troubleshooting

### GitHub Authentication Fails

**macOS**: Ensure you have an active internet connection and try running:

```bash
gh auth login --web --git-protocol https
```

### Repository Clone Fails

Ensure GitHub authentication succeeded:

```bash
gh auth status
```

If authentication is valid but clone still fails, check repository access permissions.

### Non-Git Directory at Workspace Path

If a directory already exists at `~/projects/mental-health-app-frontend` but is not a Git repository, you'll need to move or remove it before re-running the script.

````
