<p align="center">
  <img src="public/long.jpg" alt="iris logo" width="180">
</p>

# Bash Iris

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
iris <command> [args] # run a command (or use its alias)
iris --version        # show the installed version
iris --update         # compare the installed manifest with main and update if needed
iris --upgrade        # alias for --update
iris --update-deps    # update external dependencies for all scripts
```

## Commands

| Command | Alias | macOS | Linux | Description |
|---|---|---|---|---|
| `check-power` | `check` | ✅ | ❌ | Show power, sleep, and remote login config |
| `download-yt` | `download` | ✅ | ✅ | Download YouTube videos via `yt-dlp` |
| `kill-port` | `kill` | ✅ | ✅ | Kill the process running on a given port |
| `power-clean` | `clean` | ✅ | ✅ | Safe ChromePower storage analysis and cache cleanup |
| `ssh` | — | ✅ | ✅ | Generate SSH keys, configure and verify GitHub SSH access |

### `check-power` (alias: `check`)

Show Mac power configuration, sleep settings, and remote login status (macOS only).

```bash
iris check                  # Show power and sleep config (or: iris check-power)
iris check --no-sudo        # Skip remote login check (no sudo prompt)
```

### `download-yt` (alias: `download`)

Download YouTube videos via `yt-dlp` in MP4 format (H.264 + AAC) with browser cookie support for authenticated or age-gated videos.

```bash
iris download 'https://youtube.com/watch?v=...'             # Download video (or: iris download-yt)
iris download -b firefox 'https://youtube.com/watch?v=...'  # Use browser cookies (chrome, firefox, safari, etc.)
iris download -r 720 'https://youtube.com/watch?v=...'      # Limit resolution (480, 720, 1080)
iris download -p 'https://youtube.com/playlist?list=...'    # Download playlist
iris download --update-deps                                 # Update yt-dlp dependency
```

### `kill-port` (alias: `kill`)

Find and safely terminate process(es) listening on a specific port. Sends `SIGTERM` first, escalating to `SIGKILL` if the process survives.

```bash
iris kill 3000              # Terminate process on port 3000 (prompts for confirmation)
iris kill 8080 --dry-run    # Preview matching process without killing
iris kill 5432 -y           # Skip confirmation prompt
```

### `power-clean` (alias: `clean`)

Safe storage analyzer and cache cleanup tool for ChromePower profiles (`~/Documents/ChromePowerCache/chrome`).

#### Interactive Dashboard

Run without arguments to launch the interactive terminal dashboard:

```bash
iris clean                  # or: iris power-clean
```

The menu is grouped by intent and defaults to **Clean safe caches** (`[1]`), meaning simply pressing **Enter** triggers safe cleanup:

```text
  Actions:
  Cleanup
    [1] Clean safe caches (c) [Enter]        1.7 GB across 57 inactive profiles
    [2] Clean low-risk caches (l)            8.6 GB (safe + rebuildable components)

  Explore
    [3] Browse & inspect browsers (b)        59 profiles (● 2 active)
    [4] Top cleanup opportunities (t)        Ranked by reclaimable size

  Audit
    [5] Largest review data                  8.5 GB needing user decision
    [6] Largest unknown items (u)            10.9 MB unclassified data

  ────────────────────────────────────────────────────────────────────────
  [r] Refresh scan                     [q] Quit
```

- **Default Action (`[Enter]` or `1` / `c`)**: Executes safe cache cleanup across all inactive browser profiles.
- **Low-Risk Cleanup (`2` / `l`)**: Cleans component caches and ML model downloads that Chrome will automatically redownload when needed.
- **Browse & Inspect (`3` / `b` / `i`)**: Interactive browser table with sorting and per-profile cache inspection. You can also type any profile name directly at the menu prompt to inspect it.
- **Top Opportunities (`4` / `t`)**: Lists profiles with the largest reclaimable cache.
- **Audit (`5` / `6` / `u`)**: Inspect review-tier data (cookies/storage) or unclassified directories.
- **Controls (`r` / `q`)**: `r` rescans the root; `q` quits.

#### Safety Tiers & Protections

- **Active Process Protection**: Profiles currently opened in running Chrome instances are detected via process analysis & singleton locks and automatically skipped during cleanup.
- **Safe**: Safe caches (HTTP cache, GPU cache, Code Cache, media caches) that can be cleared with zero risk.
- **Low-Risk**: Rebuildable component downloads, model prediction data, and optimization guides.
- **Review**: Site storage, IndexedDB, and cookies requiring manual inspection.
- **Protected**: User credentials, login state, bookmarks, and preferences (never modified).

#### CLI Options & Automation

For non-interactive use or scheduled automation:

```bash
iris clean --dry-run                    # Preview cleanup actions without deleting (or: iris power-clean)
iris clean --clean-safe -y              # Batch clean safe caches across inactive profiles
iris clean --clean-low-risk -y          # Batch clean low-risk caches across inactive profiles
iris clean --json                       # Output full scan analysis as structured JSON
iris clean --root /path/to/chrome/cache # Specify custom ChromePower cache root
```

#### Local Testing (without system iris)

During development or when testing changes without invoking the system-installed `/usr/local/lib/iris`:

```bash
# Using uv (runs local package via virtualenv entry point)
uv run power-cleaner                     # Interactive dashboard
uv run power-cleaner --dry-run           # Dry run
uv run power-cleaner --clean-safe -y     # Batch safe clean

# Or using the repository shell script directly
./scripts/power-clean.sh --dry-run
```

### `ssh`

Generate ED25519 SSH keys, configure GitHub host aliases, and verify SSH connections.

Run without arguments to launch the interactive menu:

```bash
iris ssh
```

```text
  ⚡  iris ssh
  ────────────────────────────────────────────────────────────────────────────

  What would you like to do?

  1  Setup   — Generate SSH key & configure GitHub host alias
  2  Verify  — Test GitHub SSH host aliases
  q  Quit

  ?  Choice: 
```

Or invoke subcommands directly:

```bash
# Setup: generate key and configure ~/.ssh/config
iris ssh setup
iris ssh setup --email you@example.com --user myhandle
iris ssh setup -y

# Verify: test all GitHub SSH host aliases in ~/.ssh/config
iris ssh verify
```

## Adding a command

1. Create `scripts/<name>.sh` (or `scripts/<subdir>/<name>.sh`).
2. Add `# IRIS_DESC: <description>` near the top.
3. Add `# IRIS_PLATFORM: macos` for macOS-only commands.
4. Register the path in `SCRIPTS_COMMON` or `SCRIPTS_MACOS` in `install.sh`.

*Note: All scripts are flattened into `/usr/local/lib/iris/` during installation.*

### Commands with Python dependencies

If a command wraps a Python package (like `power-clean`), place the package under `src/<package_name>/` and install it alongside the shell script in `install.sh`. The shell wrapper sets `PYTHONPATH` at runtime so no `pip install` is needed.

## Development

```bash
# Setup dependencies
uv sync

# Run power-cleaner locally
uv run power-cleaner --dry-run

# Run Python tests
uv run pytest
# or: make py-test

# Shell formatting & linting
make fmt-check
make lint

# Full test & lint check
make check
```

## Documentation

- [Development](./docs/DEVELOPMENT.md) — Tooling, formatting, and linting setup.
- [Releasing](./docs/RELEASING.md) — Release workflow, versioning, and Conventional Commits.