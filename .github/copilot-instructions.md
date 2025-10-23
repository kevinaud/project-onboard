# Project Onboard – Copilot-Only Execution Guide

This playbook addresses you, the AI coding agent. Humans do not read this file, so interpret every directive as a requirement for your workflow.

## Orientation
- You maintain the cross-platform onboarding runner. Iteration 0 remains dry-run only until PRDs expand its scope.
- Keep `setup.sh` (Bash) and `setup.ps1` (PowerShell) feature-parallel by relying on shared helpers in `scripts/`.
- Preserve `min-dotfiles/` for iterations that explicitly hydrate it; never add side effects ahead of schedule.

## Task Management Protocol
- NOTE: YOU MUST USE "/home/kevin/projects" AS THE WORKING DIRECTORY PARAMETER THAT YOU PASS TO THE MCP AGENTIC TOOLS COMMANDS BELOW.
- Treat the MCP project `Cross-Platform Developer Onboarding System` as the single source of truth for scope. Never implement a feature that lacks an open iteration subtask.
- Before touching code, call `mcp_agentic-tools_list_tasks` for that project and locate the current iteration under `Iteration Delivery Roadmap > Iteration N`. Expand its children so you see the ordered subtasks (Pre-flight, Baseline QA, Delivery, plus iteration-specific build/custom work).
- Work strictly top-to-bottom within the iteration: complete the `Pre-flight: Read PRDs & Sync Repos` subtask, then the build/implementation subtasks, run `Baseline QA & Dry-Run Enforcement`, and finish with `Delivery: Commit, PR, and CI Stewardship`.
- Whenever you begin a subtask, immediately call `mcp_agentic-tools_update_task` to set `status` to `in-progress`; on completion, set `status` to `done` and add concise completion notes if the tool supports them. Never leave a finished subtask pending.
- If an iteration requires extra steps, create additional subtasks under that iteration via `mcp_agentic-tools_create_task` instead of tracking work ad hoc. Document why the new subtask exists inside its details.
- After every major coding action (new file, refactor, README update), re-run `mcp_agentic-tools_list_tasks` to confirm no remaining subtasks are blocked and to surface the next actionable item. Do not mark the parent iteration task complete until every child reports `status: done`.

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
- ALL GITHUB INTERACTION MUST BE DONE VIA THE SUITE OF MCP AGENTIC TOOLS FOR GITHUB THAT HAVE BEEN MADE AVAILABLE TO YOU.

## Adding Features
- Align work strictly with the PRDs; do not expand scope on your own.
- Gate host modifications or installers behind flags and respect dry-run mode so CI and early runs remain side-effect free.
- Maintain cross-platform parity. When asymmetric behavior is unavoidable, document it in code comments and the README during the same iteration.

## Validation & Conventions
- Treat the `announce_plan` output as a contract and update it whenever behavior changes.
- Keep Bash scripts POSIX-friendly (macOS default bash compatible) and PowerShell scripts PowerShell Core compatible.
- Even without formal tests, run the lint commands above and execute entry points with `--dry-run`/`-DryRun` to confirm they only log planned actions.
