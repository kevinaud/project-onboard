# Project Onboard

Early iteration of the cross-platform onboarding tooling. Iteration 1 focuses on
platform detection, structured logging, and enforcing dry-run behaviour so future
steps can evolve safely.

## Usage

```bash
./setup.sh --dry-run --verbose
```

Available flags:

- `--dry-run` (default): print planned actions only.
- `--non-interactive`: assume default answers to prompts.
- `--no-optional`: skip optional features.
- `--verbose`: emit verbose diagnostics.
- `--workspace <path>`: override the default workspace directory (`~/projects`).

> **Note**
> Dry-run mode is enforced during early iterations. No host changes are performed yet.

Windows users can invoke `./setup.ps1` to see the current status; the full wrapper
will arrive in later iterations.

## Tests

Run Bats tests from the repository root:

```bash
bats tests
```

ShellCheck is also recommended: `shellcheck -x setup.sh scripts/*.sh`.
