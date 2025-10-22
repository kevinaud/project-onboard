# Project Onboard – AI Coding Agent Guide

## Orientation
- The repo scaffolds a cross-platform onboarding runner; iteration 0 prints an execution plan only. Future work should keep dry-run behavior unless the PRD updates the iteration scope.
- Entry points: `setup.sh` (Bash) and `setup.ps1` (PowerShell). They share helpers under `scripts/` and must stay feature-parallel.
- The lightweight `min-dotfiles/` directory is a placeholder for assets that later iterations will hydrate—do not add config side effects yet.

## Script Patterns
- Both entry points source/import `scripts/utils.sh` and `scripts/detect.sh` equivalents; reuse these helpers instead of re-implementing logging or detection.
- Flag handling is centralized in each entry point and must align between shells (`--non-interactive` ↔ `-NonInteractive`, etc.). Any new flag needs dual implementation plus README updates.
- Dry-run enforcement: `setup.sh` flips `DRY_RUN` to true; `setup.ps1` warns and forces `$DryRun`. Preserve that guardrail until the roadmap says otherwise.
- Logging helpers (`log_info`, `log_warn`, `log_error`, `log_verbose`, `announce_plan`) output plain text for now. Add new messaging APIs here so both shells stay in sync.
- `detect_environment` returns a JSON snippet with OS/arch/host context; extend this function rather than sprinkling `uname`/`RuntimeInformation` calls elsewhere.

## Developer Workflow
- Before starting an iteration: read every document in `/home/kevin/projects/prds/` to confirm scope, then `git fetch origin`, `git checkout main`, `git pull`, and create a fresh branch (`git checkout -b iteration-X-scope`) to keep iteration work isolated.
- CI runs ShellCheck and PSScriptAnalyzer via `.github/workflows/ci.yml`. Mirror those locally with:
  - `shellcheck -x setup.sh scripts/*.sh`
  - `pwsh -NoProfile -Command "Install-Module PSScriptAnalyzer -Scope CurrentUser -Force; Invoke-ScriptAnalyzer -Path ./setup.ps1 -EnableExit"`
- README usage examples must stay correct whenever the CLI surface changes. Update both Bash and PowerShell snippets together.
- Prefer small, composable helpers in `scripts/` to keep entry-point scripts easy to scan. New shared logic belongs in `scripts/` with accompanying comments describing iteration intent.
- When an iteration is ready, always open a PR from the iteration branch to `main`, verify every GitHub Actions job, and fix issues until CI and PR checks are green before handing off for review.

## Adding Features
- Check the PRDs in `/home/kevin/projects/prds/` before expanding scope; iterations align with those docs.
- When introducing host mutations or installers, gate them behind flags and dry-run checks so CI and early runs remain side-effect free.
- Maintain cross-platform parity: if a change affects only one host, explain the asymmetry in code comments and the README.

## Validation & Conventions
- Treat the plan output (`announce_plan`) as a contract—update the bullet list when behavior changes.
- Keep scripts POSIX-compatible Bash (avoid `[[` features unsupported on macOS default bash if targeted) and PowerShell Core friendly.
- No tests exist yet; emulate CI lint jobs and run the entry points with `--dry-run`/`-DryRun` to confirm they only print.
