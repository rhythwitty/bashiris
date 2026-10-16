# iris

A unified CLI for utility scripts on macOS and Linux.

## Install

```bash
curl -sL https://github.com/rhythwitty/bashiris/raw/main/install.sh | bash
```

The installer detects your OS, installs only compatible scripts, and saves the release manifest used for version checks.

## Uninstall

To remove `iris` and all its installed scripts from your system, run:

```bash
curl -sL https://github.com/rhythwitty/bashiris/raw/main/uninstall.sh | bash
```

## Usage

```bash
iris                  # list available commands
iris <command> [args] # run a command
iris --version        # show the installed version
iris --update         # compare the installed manifest with main and update if needed
iris --upgrade        # alias for --update
iris --update-deps    # update external dependencies for all scripts
```

## Commands

| Command | macOS | Linux | Description |
|---|---|---|---|
| `check-power` | ✅ | ❌ | Show power, sleep, and remote login config |
| `download-yt` | ✅ | ✅ | Download YouTube videos via `yt-dlp` |
| `kill-port` | ✅ | ✅ | Kill the process running on a given port |
| `power-clean` | ✅ | ✅ | Safe ChromePower storage analysis and cache cleanup |
| `ssh-setup` | ✅ | ✅ | Generate SSH keys and configure GitHub access |
| `ssh-verify` | ✅ | ✅ | Verify GitHub SSH host aliases from `~/.ssh/config` |

## Adding a command

1. Create `scripts/<name>.sh` (or `scripts/<subdir>/<name>.sh`).
2. Add `# IRIS_DESC: <description>` near the top.
3. Add `# IRIS_PLATFORM: macos` for macOS-only commands.
4. Register the path in `SCRIPTS_COMMON` or `SCRIPTS_MACOS` in `install.sh`.

*Note: All scripts are flattened into `/usr/local/lib/iris/` during installation.*

### Commands with Python dependencies

If a command wraps a Python package (like `power-clean`), place the package under `scripts/<package_name>/` and install it alongside the shell script in `install.sh`. The shell wrapper sets `PYTHONPATH` at runtime so no `pip install` is needed.

## Development

```bash
# Shell formatting & linting
make fmt-check
make lint

# Python linting (requires ruff: pip install ruff)
make py-lint

# Python tests
make py-test

# Run everything
make check
```

## Documentation

- [Development](./docs/DEVELOPMENT.md) — Tooling, formatting, and linting setup.
- [Releasing](./docs/RELEASING.md) — Release workflow, versioning, and Conventional Commits.