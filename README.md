# iris

A unified CLI for utility scripts. Works on macOS and Linux.

## Install

```bash
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/install.sh | bash
```

The installer detects your OS and only installs compatible scripts.

## Usage

```bash
iris                    # list available commands
iris <command> [args]   # run a command
iris --update           # update iris and all scripts (checks version first)
iris --upgrade          # alias for --update
iris --version          # show version
```

## Commands

| Command | macOS | Linux | Description |
|---|---|---|---|
| `check-power` | ✅ | ❌ | Show power, sleep, and remote login config |
| `download-yt` | ✅ | ✅ | Download YouTube videos via yt-dlp |
| `kill-port`   | ✅ | ✅ | Kill the process running on a given port |
| `setup-ssh`   | ✅ | ✅ | Generate SSH keys and configure GitHub access |

### check-power _(macOS only)_
```bash
iris check-power
```

### download-yt
```bash
iris download-yt https://youtube.com/watch?v=...
iris download-yt -b firefox -r 720 https://...
iris download-yt --browser safari --resolution 480 https://...
iris download-yt --update ytdlp
iris download-yt --help
```

### kill-port
```bash
iris kill-port <port_number>
```

### setup-ssh
```bash
iris setup-ssh
```

## Adding a new command

1. Create `scripts/<command-name>.sh` with `# IRIS_DESC: <description>` near the top
2. Add `# IRIS_PLATFORM: macos` if macOS-only; omit for cross-platform
3. Add the command name to `SCRIPTS_COMMON` or `SCRIPTS_MACOS` in `install.sh`

## Releasing

Version management and releases are automated using **Conventional Commits** and **GitHub Actions**.

See [RELEASING.md](./RELEASING.md) for detailed instructions on how to bump versions and publish new releases.