# Project Onboard – Copilot-Only Execution Guide

This playbook addresses you, the AI coding agent. Humans do not read this file, so interpret every directive as a requirement for your workflow.

## Orientation
- You maintain the cross-platform onboarding runner. Iteration 0 remains dry-run only until PRDs expand its scope.
- Keep `setup.sh` (Bash) and `setup.ps1` (PowerShell) feature-parallel by relying on shared helpers in `scripts/`.
- Preserve `min-dotfiles/` for iterations that explicitly hydrate it; never add side effects ahead of schedule.

## Script Patterns
- Always source/import `scripts/utils.sh` and `scripts/detect.sh`; do not duplicate logging or detection logic.
- Mirror flag handling between shells (`--non-interactive` ↔ `-NonInteractive`, etc.), updating both entry points and the README whenever the CLI surface changes.
- Enforce dry-run defaults: `setup.sh` sets `DRY_RUN=true`, `setup.ps1` warns and forces `$DryRun` until a roadmap update says otherwise.
- Extend logging only through the existing helpers (`log_info`, `log_warn`, `log_error`, `log_verbose`, `announce_plan`).
- Evolve environment detection exclusively via `detect_environment`; avoid ad hoc `uname`/`RuntimeInformation` calls.

## Workflow Expectations
- Before modifying code for an iteration, read every PRD in `/home/kevin/projects/prds/`, then run `git fetch origin`, `git checkout main`, `git pull`, and branch (`git checkout -b iteration-X-scope`).
- Replicate CI locally:
  - `shellcheck -x setup.sh scripts/*.sh`
  - `pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force; Invoke-ScriptAnalyzer -Path ./setup.ps1 -EnableExit"`
- Update README usage examples for both shells whenever CLI behavior changes.
- Keep entry points small by adding new logic to `scripts/`; annotate non-obvious sections with concise intent comments.
- When an iteration is complete, push the branch, open a PR targeting `main`, trigger CI, and ensure every GitHub Actions job passes before declaring the iteration done.

## Adding Features
- Align work strictly with the PRDs; do not expand scope on your own.
- Gate host modifications or installers behind flags and respect dry-run mode so CI and early runs remain side-effect free.
- Maintain cross-platform parity. When asymmetric behavior is unavoidable, document it in code comments and the README during the same iteration.

## Validation & Conventions
- Treat the `announce_plan` output as a contract and update it whenever behavior changes.
- Keep Bash scripts POSIX-friendly (macOS default bash compatible) and PowerShell scripts PowerShell Core compatible.
- Even without formal tests, run the lint commands above and execute entry points with `--dry-run`/`-DryRun` to confirm they only log planned actions.
