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

Use the reusable timeout wrapper to keep long-running validations from hanging:

```bash
./scripts/run_with_timeout.sh 300 -- pwsh -File ./setup.ps1 -DryRun -NonInteractive
./scripts/run_with_timeout.sh 300 -- pwsh -NoProfile -Command "Invoke-Pester -Path tests/setup.Tests.ps1"
```

## GitHub Actions

### Windows E2E Onboarding Workflow

The `.github/workflows/e2e-windows.yml` workflow provisions a Windows runner, enables WSL, installs Docker Engine inside Ubuntu, and executes the full onboarding flow including the Dev Container bring-up for `mental-health-app-frontend`.

| Requirement | Value |
| --- | --- |
| Trigger | `push` to `main`, pull requests targeting `main`, or manual `workflow_dispatch` |
| Required secret | `PROJECT_ONBOARD_PAT` |

You must provide a repository or organization secret named `PROJECT_ONBOARD_PAT` containing a GitHub personal access token with at least the `repo` scope so the workflow can clone the private `psps-mental-health-app/mental-health-app-frontend` repository inside WSL. The workflow uploads a `devcontainer-log` artifact to help troubleshoot `devcontainer up` failures and always prunes Docker resources before exiting.

To simplify managing that secret, run `scripts/manage_pat_secret.sh` from a workstation that already has the GitHub CLI authenticated and provide the PAT you created:

```bash
./scripts/manage_pat_secret.sh --token-value "$PROJECT_ONBOARD_PAT"
```

You can alternatively read the token from a file (for example one produced by a password manager export):

```bash
./scripts/manage_pat_secret.sh --token-file /path/to/token.txt
```

The helper validates the input, then stores it as the `PROJECT_ONBOARD_PAT` Actions secret for the current repository. Use `--dry-run` to preview the action, or `--repo owner/name` to target a different repository. The script never mutates your GitHub CLI credentials; it only uploads the PAT you pass in.

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
