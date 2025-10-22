# project-onboard

Project onboarding runner that coordinates host bootstrap tasks across Windows, WSL, macOS, and DevContainers. Iteration 0 focuses on scaffolding and well-defined flags without making any host changes.

## Usage

```bash
./setup.sh [flags]
```

```powershell
./setup.ps1 [-Flags]
```

Both entry points currently print an execution plan only—they do not modify the system.

### Flags

- `--non-interactive` / `-NonInteractive` – suppress interactive prompts. Planned for future iterations.
- `--no-optional` / `-NoOptional` – skip optional extras (reserved).
- `--dry-run` / `-DryRun` – ensure no side effects. Iteration 0 always behaves as a dry run.
- `--verbose` / `-Verbose` – increase logging verbosity.
- `--workspace <path>` / `-Workspace <path>` – override the default `~/projects` workspace.

## Roadmap

This repository follows the staged iterations defined in the PRD. Iteration 0 establishes:

- Script entry points with shared flag parsing.
- Guardrail messaging that clarifies no actions are performed yet.
- Shared script helpers (`scripts/`) and placeholder dotfiles directory (`min-dotfiles/`).
- Initial CI placeholders running ShellCheck and PSScriptAnalyzer to keep the scaffolding healthy.

Subsequent iterations will layer in detection, installs, and real configuration.