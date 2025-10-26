# Project Onboard

Cross-platform onboarding tooling for the mental-health-app-frontend project. This repository provides automated setup for macOS and WSL (Ubuntu) environments, including prerequisite installation, GitHub authentication, and private repository cloning.

## Quick Start

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash
```

To test another branch, append `--branch <name>` or wrap the pipeline so the environment variable survives the subshell:

```bash
curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash -s -- --branch iter-9
# or
PROJECT_ONBOARD_BRANCH=iter-9 bash -c 'curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash'
```

### Windows (WSL)

Paste this single command into an elevated PowerShell terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.ps1 | Invoke-Expression"
```

The Windows script enables WSL, guides you through the first Ubuntu launch, and then automatically hands off to the Linux bootstrap step inside WSL. Use `-Branch <name>` if you need to try a preview branch (for example, `-Branch iter-9`).

To pin the Windows bootstrap to another branch directly from the one-liner, set the environment variable first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:PROJECT_ONBOARD_BRANCH='iter-9'; Invoke-RestMethod https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.ps1 | Invoke-Expression"
```

> **Tip**
> When the script enables the WSL features for the first time, Windows usually requires a reboot before Ubuntu can be installed. If prompted, restart Windows and re-run `setup.ps1`; the onboarding flow will resume where it left off.

## Usage

```bash
./setup.sh [options]
```

Available options:

- `--dry-run`: Print planned actions only, no host changes.
- `--non-interactive`: Assume default answers to prompts.
- `--no-optional`: Skip optional features.
- `--verbose`: Emit verbose diagnostics.
- `--branch <name>`: Download helper assets from the specified `project-onboard` branch (default: `main`).
- `--workspace <path>`: Override the default workspace directory (default: `~/projects`).
- `--help`: Show help message.

Use `--dry-run` if you want to preview actions before executing them.

You can also set the environment variable `PROJECT_ONBOARD_BRANCH=<name>` to pin every step (PowerShell and WSL/macOS) to a specific branch without passing the flag on every command. When you pipe the installer, wrap it in a subshell (for example `PROJECT_ONBOARD_BRANCH=iter-9 bash -c 'curl -fsSL https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh | bash'`) so the variable reaches the invoked script.

## What It Does

The onboarding flow performs the following high-level tasks:

1. **Platform Detection**: Identifies macOS (Intel/Apple Silicon) or WSL (Ubuntu).
2. **Prerequisites**: Installs Homebrew, Git, GitHub CLI, and chezmoi as needed.
3. **Git Identity**: Prompts for `user.name` and `user.email` if not already configured.
4. **Git Config**: Applies minimal project-required `.gitconfig` with safe backup.
5. **GitHub Auth**: 
   - **macOS**: Runs `gh auth login --web` (browser-based).
   - **WSL**: Uses the Windows Git Credential Manager flow triggered from PowerShell.
6. **Clone Repository**: Clones the private `mental-health-app-frontend` repository to `~/projects` (or specified workspace).
7. **Docker Integration (WSL)**: Confirms Docker Desktop integration with your Ubuntu distribution.

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
