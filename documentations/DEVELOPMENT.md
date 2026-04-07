# Development

This project uses `shfmt` for formatting and `shellcheck` for linting.

## Tools

- **shfmt**: Formats shell scripts with 4-space indentation and simplified redirects.
- **shellcheck**: Static analysis tool for shell scripts to catch bugs and portability issues.

## Usage

Run these commands from the root of the repository:

```bash
make fmt    # Format all shell scripts
make lint   # Run lint checks
make check  # Run both formatting and lint checks (used by CI)
```

## Git Hooks

A pre-commit hook is provided to ensure code quality before every commit. To enable it, run:

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

## CI/CD

GitHub Actions automatically runs `make check` on every push to `main` and on all pull requests.
