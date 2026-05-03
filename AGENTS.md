# AGENTS.md — iris Codebase Guide

This file helps AI coding assistants understand the structure, conventions, and patterns of this repo.

## Overview

**iris** is a unified CLI dispatcher for bash utility scripts. A single `iris` binary routes subcommands to individual scripts stored in `/usr/local/lib/iris/`. Supports macOS and Linux.

## Repository Structure

```
/
├── iris              # Dispatcher → installed to /usr/local/bin/iris
├── install.sh        # Installer: downloads iris + scripts to correct locations
├── scripts/          # Individual command scripts → installed to /usr/local/lib/iris/
│   ├── check-power.sh   (macOS only — uses pmset, systemsetup)
│   ├── download-yt.sh   (cross-platform)
│   ├── kill-port.sh     (cross-platform)
│   └── setup-ssh.sh     (cross-platform)
├── README.md
└── AGENTS.md         # This file
```

## Script Metadata Conventions

Every script in `scripts/` must include these metadata comments near the top (after the shebang and comment block):

```bash
# IRIS_DESC: <one-line description>     # Required — shown in `iris` help listing
# IRIS_PLATFORM: macos                  # Optional — omit entirely if cross-platform
```

- `IRIS_DESC` is read at runtime by the `iris` dispatcher to build the auto-generated help output.
- `IRIS_PLATFORM` is checked before `exec`-ing a script. If the current OS doesn't match, `iris` exits with an error. Accepted values: `macos`, `linux`.
- Scripts with no `IRIS_PLATFORM` tag are assumed cross-platform.

## Dispatcher Logic (`iris`)

```
iris                 →  show_help() — scans IRIS_LIB_DIR/*.sh, reads IRIS_DESC per script
iris --version       →  print IRIS_VERSION
iris --update        →  curl install.sh from GitHub | bash
iris <command> [args]
  1. Resolve IRIS_LIB_DIR/<command>.sh
  2. Read IRIS_PLATFORM tag; exit 1 if platform mismatch
  3. exec the script, forwarding all remaining args
```

Key variables in `iris`:

| Variable          | Value                                           |
|-------------------|-------------------------------------------------|
| `IRIS_VERSION`    | Current semver string (e.g. `1.0.0`)           |
| `IRIS_LIB_DIR`    | `/usr/local/lib/iris`                           |
| `IRIS_UPDATE_URL` | GitHub raw URL to `install.sh`                  |

## Installer Logic (`install.sh`)

- Detects `PLATFORM` via `uname -s` (`Darwin` = macOS, `Linux` = Linux)
- `SCRIPTS_COMMON` — installed on both platforms
- `SCRIPTS_MACOS` — installed on macOS only; skipped on Linux
- Downloads each script to `/tmp/iris_<name>.sh`, `chmod +x`, then `sudo mv` to `IRIS_LIB`
- Downloads `iris` dispatcher to `/usr/local/bin/iris`
- `iris --update` re-runs this installer from GitHub (idempotent)

## Platform Support

| Script       | macOS | Linux | Reason for restriction              |
|--------------|-------|-------|-------------------------------------|
| `download-yt`| ✅    | ✅    |                                     |
| `kill-port`  | ✅    | ✅    |                                     |
| `setup-ssh`  | ✅    | ✅    |                                     |
| `check-power`| ✅    | ❌    | Uses `pmset` and `systemsetup` (macOS only) |

## How to Add a New Command

1. Create `scripts/<command-name>.sh` (use kebab-case)
2. Add metadata near the top:
   ```bash
   # IRIS_DESC: Short description shown in iris help
   # IRIS_PLATFORM: macos   # only if macOS-specific; omit otherwise
   ```
3. Add command name to `SCRIPTS_COMMON` or `SCRIPTS_MACOS` in `install.sh`
4. The script receives its own args directly — no iris-specific handling needed
5. Each script should handle its own `--help` flag independently

## Naming Conventions

- Script filenames use **kebab-case**: `check-power.sh`, not `checkpower.sh`
- Command names (as called via `iris`) match the filename without `.sh`
- Scripts are standalone — they work without `iris` if called directly

## Script Independence Principle

Scripts do not depend on each other and do not need to know they are run under `iris`.
The dispatcher is a thin shim: it only resolves the script path, checks platform, and `exec`s.
