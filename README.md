# iris

A unified CLI for utility scripts on macOS and Linux.

## Install

```bash
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/install.sh | bash
```

The installer detects your OS, installs only compatible scripts, and saves the release manifest used for version checks.

## Uninstall

To remove `iris` and all its installed scripts from your system, run:

```bash
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/uninstall.sh | bash
```

## Usage

```bash
iris                  # list available commands
iris <command> [args] # run a command
iris --version        # show the installed version
iris --update         # compare the installed manifest with main and update if needed
iris --upgrade        # alias for --update
```

## Commands

| Command | macOS | Linux | Description |
|---|---|---|---|
| `check-power` | ✅ | ❌ | Show power, sleep, and remote login config |
| `download-yt` | ✅ | ✅ | Download YouTube videos via `yt-dlp` |
| `kill-port` | ✅ | ✅ | Kill the process running on a given port |
| `setup-ssh` | ✅ | ✅ | Generate SSH keys and configure GitHub access |
| `verify-ssh` | ✅ | ✅ | Verify GitHub SSH host aliases from `~/.ssh/config` |

## Adding a command

1. Create `scripts/<command-name>.sh`.
2. Add `# IRIS_DESC: <description>` near the top.
3. Add `# IRIS_PLATFORM: macos` for macOS-only commands.
4. Register the command in `SCRIPTS_COMMON` or `SCRIPTS_MACOS` in `install.sh`.

## Documentation

- [Development](./documentations/DEVELOPMENT.md) — Tooling, formatting, and linting setup.
- [Releasing](./documentations/RELEASING.md) — Release workflow, versioning, and Conventional Commits.
