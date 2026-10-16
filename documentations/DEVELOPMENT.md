# Development

This project uses `shfmt` and `shellcheck` for shell scripts, and `ruff`, `pytest`, and `uv` for Python components (`power_cleaner`).

## Tools

### Shell
- **shfmt**: Formats shell scripts with 4-space indentation and simplified redirects.
- **shellcheck**: Static analysis tool for shell scripts to catch bugs and portability issues.

### Python
- **ruff**: Fast linter and code formatter for Python (`src/power_cleaner` and `tests`).
- **pytest** / **unittest**: Test runners for testing `power_cleaner` storage scanning and cleanup logic.
- **uv**: Fast Python package and project manager.

## Setup

Sync Python development dependencies using `uv`:

```bash
uv sync
```

## Usage

Run these commands from the root of the repository:

```bash
# Shell
make fmt        # Format all shell scripts
make fmt-check  # Check shell script formatting
make lint       # Run shellcheck linting

# Python
make py-lint    # Run ruff lint checks
make py-test    # Run Python unit tests

# Full check (used by CI and pre-commit)
make check      # Run formatting, linting, and all tests
```

You can also run tests directly with `pytest`:

```bash
uv run pytest
```

## Git Hooks

A pre-commit hook is provided to ensure code quality before every commit (runs `make check`). To enable it, run:

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

## CI/CD

GitHub Actions runs both shell verification (`shfmt`, `shellcheck`) and Python checks (`ruff`, `pytest`) on every push to `main` and on all pull requests.

