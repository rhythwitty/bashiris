<p align="center">
  <img src="public/long.jpg" alt="iris logo" width="180">
</p>

# Bash Iris

Modular CLI dispatcher for system administration, storage reclamation, network diagnostics, and credential management on macOS and Linux.

---

## Architecture & Installation

Iris installs a global dispatcher binary (`/usr/local/bin/iris`) and modular command scripts into `/usr/local/lib/iris`. The installer detects the host OS, filters scripts by platform compatibility, and caches `.release-please-manifest.json` for version reconciliation.

### Install

```bash
curl -sL https://github.com/rhythwitty/bashiris/raw/main/install.sh | bash
```

### Uninstall

```bash
curl -sL https://github.com/rhythwitty/bashiris/raw/main/uninstall.sh | bash
```

---

## Global CLI Usage

```bash
iris                          # List installed commands and aliases
iris <command|alias> [args]   # Execute a subcommand
iris --version                # Output version from local release manifest
iris --update                 # Fetch remote manifest from main and upgrade if outdated
iris --update-deps            # Trigger upstream dependency updates across subcommands
```

---

## Command Matrix

| Command | Alias | macOS | Linux | Implementation & Technical Scope |
|---|---|:---:|:---:|---|
| `check-power` | `check` | ✅ | ❌ | Audits PM subsystems (`pmset`) and SSH remote login (`systemsetup`). |
| `download-yt` | `download` | ✅ | ✅ | Stream extraction wrapper for `yt-dlp` enforcing H.264/AAC with browser session cookie injection. |
| `kill-port` | `kill` | ✅ | ✅ | Inspects socket listeners via `lsof` and executes graceful `SIGTERM` → `SIGKILL` escalation. |
| `power-clean` | `clean` | ✅ | ✅ | Storage analyzer and multi-tier cache reclamation engine for ChromePower profiles with PID lock safety. |
| `ssh` | — | ✅ | ✅ | Automates `ed25519` keypair generation, `~/.ssh/config` stanza templating, and GitHub handshake verification. |

---

## Subcommands

### `check-power` (alias: `check`)

Audits macOS power management, sleep state machines, power assertions (`pmset -g live`, `pmset -g assertions`), battery telemetry (`pmset -g batt`), and remote login configuration (`systemsetup`).

```bash
iris check            # Execute complete audit (prompts sudo for systemsetup)
iris check --no-sudo  # Omit remote login audit to run non-interactively
```

---

### `download-yt` (alias: `download`)

Wraps `yt-dlp` to enforce standard container outputs (`MP4` container with H.264 video and AAC audio). Supports browser cookie extraction (`--cookies-from-browser`) to bypass bot checks and handle authenticated, members-only, or age-gated media.

```bash
iris download <url>                     # Interactive stream/resolution selection
iris download -b chrome <url>           # Decrypt session cookies from browser (chrome, firefox, safari, etc.)
iris download -r 1080 <url>             # Set upper resolution bound (480, 720, 1080)
iris download -p <playlist_url>         # Batch download playlist
iris download --update-deps             # Update underlying yt-dlp binary
```

---

### `kill-port` (alias: `kill`)

Queries listening TCP sockets via `lsof -iTCP:<port> -sTCP:LISTEN` and terminates target PIDs. Dispatches `SIGTERM` for graceful shutdown, polling process death before escalating to `SIGKILL` (`kill -9`).

```bash
iris kill 3000          # Interactive termination with PID details
iris kill 8080 --dry-run # Scan and print target PID without signaling
iris kill 5432 -y       # Non-interactive termination (bypasses prompt)
```

---

### `power-clean` (alias: `clean`)

Storage analyzer and cache reclamation engine targeting ChromePower profile trees (`~/Documents/ChromePowerCache/chrome`). Powered by the bundled `power_cleaner` Python module.

#### Process Safety & Data Classification
- **Active Process Guard**: Inspects Chromium `SingletonLock` symlink targets and OS process tables (`ps`). Active profiles are excluded from mutation.
- **Safe Tier**: Volatile caches (`Cache_Data`, `GPUCache`, V8 Code Cache, media caches). Cleared with zero state loss.
- **Low-Risk Tier**: Component updates, optimization guides, and ML models. Rebuilt automatically on subsequent launches.
- **Review Tier**: Site storage, IndexedDB, WebSQL, and Service Worker storage requiring manual clearance.
- **Protected Tier**: Session cookies, SQLite keyrings (`Login Data`, `Web Data`), and profile preferences. Strictly immutable.

#### Execution Modes

```bash
# Interactive TUI dashboard
iris clean

# Non-interactive CLI & Automation
iris clean --clean-safe -y              # Headless cleanup of safe caches across inactive profiles
iris clean --clean-low-risk -y          # Headless cleanup including low-risk rebuildable assets
iris clean --dry-run                    # Simulate deletions and report reclaimable bytes
iris clean --json                       # Emit profile scan metrics as structured JSON
iris clean --root /custom/chrome/path   # Target custom profile root directory
```

---

### `ssh`

Automates OpenSSH key provisioning and client configuration for multiple GitHub identities.

```bash
iris ssh                # Launch interactive menu
```

#### Subcommands

- **`setup`**: Generates an `ed25519` keypair (`ssh-keygen -t ed25519 -C <email>`), provisions identity stanzas in `~/.ssh/config` (`Host github-<user>`, `HostName github.com`, `User git`, `IdentityFile ...`), and outputs the public key.
  ```bash
  iris ssh setup --email dev@example.com --user octocat -y
  ```
- **`verify`**: Evaluates all configured GitHub SSH host aliases by issuing non-interactive authentication probes (`ssh -T git@<host>`).
  ```bash
  iris ssh verify
  ```

---

## Extension Protocol

To add a command to the dispatcher:

1. Create `scripts/<command_name>.sh` (executable permissions: `chmod +x`).
2. Add metadata header annotations:
   ```bash
   # IRIS_DESC: Short description displayed in iris --help
   # IRIS_PLATFORM: macos # Omit for cross-platform, or specify 'macos' / 'linux'
   ```
3. Source the shared library:
   ```bash
   _COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
   [[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
   source "$_COMMON"
   ```
4. Register the script path in `SCRIPTS_COMMON` or `SCRIPTS_MACOS` within `install.sh`.

### Python Subsystems

For commands requiring Python packages (e.g. `power_cleaner`):
- Place source under `src/<package_name>/`.
- The shell script wrapper in `scripts/` resolves `PYTHONPATH` dynamically to `/usr/local/lib/iris/src`, eliminating external `pip` install requirements at runtime.

---

## Development

```bash
# Sync virtualenv and development dependencies
uv sync

# Run test suite
uv run pytest
# or: make py-test

# Static analysis and formatting
make fmt-check    # shfmt
make lint         # shellcheck + ruff
make check        # Complete test and lint validation
```

---

## Documentation

- [Development Guide](./docs/DEVELOPMENT.md) — Tooling, linting, and environment setup.
- [Release Process](./docs/RELEASING.md) — Conventional Commits and Release Please automation.
