#!/bin/bash

# ─────────────────────────────────────────────
#  power-clean — ChromePower storage analyzer & cache cleaner
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Safe ChromePower storage analyzer and cache cleanup

# ── Terminal color detection ──────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput &> /dev/null && [[ -z "${NO_COLOR:-}" ]]; then
    BOLD=$(tput bold 2> /dev/null || true)
    RESET=$(tput sgr0 2> /dev/null || true)
    CYAN=$(tput setaf 6 2> /dev/null || true)
    GREEN=$(tput setaf 2 2> /dev/null || true)
    RED=$(tput setaf 1 2> /dev/null || true)
    DIM=$(tput dim 2> /dev/null || true)
else
    BOLD="" RESET="" CYAN="" GREEN="" RED="" DIM=""
fi

show_help() {
    cat << EOF

${BOLD}${CYAN}  ╭──────────────────────────────────────────╮${RESET}
${BOLD}${CYAN}  │${RESET}  ${BOLD}⚡  ChromePower Cleaner${RESET}${BOLD}${CYAN}                  │${RESET}
${BOLD}${CYAN}  │${RESET}${DIM}     power-clean — help & usage${RESET}${BOLD}${CYAN}            │${RESET}
${BOLD}${CYAN}  ╰──────────────────────────────────────────╯${RESET}

${BOLD}USAGE${RESET}
    iris power-clean ${DIM}[OPTIONS]${RESET}
    power-clean      ${DIM}[OPTIONS]${RESET}

${BOLD}DESCRIPTION${RESET}
    ${DIM}Safe ChromePower storage analysis and cache cleanup tool.
    Accounts for all storage, protects active Chrome instances,
    and safely cleans regenerable caches without removing user data.${RESET}

    ${CYAN}Default root:${RESET}  ~/Documents/ChromePowerCache/chrome
    ${CYAN}Override with:${RESET} export CHROME_POWER_ROOT=/path/to/chrome

${BOLD}OPTIONS${RESET}
    ${CYAN}-h, --help${RESET}              Show this help message
    ${CYAN}--root${RESET} ${DIM}<path>${RESET}           ChromePower cache root path
    ${CYAN}--dry-run${RESET}               Show cleanup actions without deleting anything
    ${CYAN}--clean-safe${RESET}            Batch clean ${GREEN}safe${RESET} (regenerable) caches
    ${CYAN}--clean-low-risk${RESET}        Batch clean ${CYAN}low-risk${RESET} caches
    ${CYAN}-y, --yes, --no-confirm${RESET} Bypass interactive confirmation prompts
    ${CYAN}--json${RESET}                  Output full analysis as JSON to stdout and exit
    ${CYAN}--version${RESET}               Show version number

${BOLD}EXAMPLES${RESET}
    ${DIM}iris power-clean${RESET}
    ${DIM}iris power-clean --dry-run${RESET}
    ${DIM}iris power-clean --clean-safe -y${RESET}
    ${DIM}iris power-clean --clean-low-risk${RESET}
    ${DIM}iris power-clean --root ~/Documents/ChromePowerCache/chrome${RESET}

EOF
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if ! command -v python3 &> /dev/null; then
    echo "" >&2
    echo "  ${RED}⊘${RESET}  ${BOLD}python3 is required but not found in PATH.${RESET}" >&2
    echo "" >&2
    exit 1
fi

# Detect platform and library dir
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    IRIS_LIB_DIR="$HOME/.local/lib/iris"
else
    IRIS_LIB_DIR="/usr/local/lib/iris"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the directory that contains the power_cleaner Python package.
# After installation the package lives beside this script in $IRIS_LIB_DIR.
# During development it lives in scripts/power_cleaner/ relative to the repo root.
find_package_dir() {
    # 1. Beside this script (installed location: $IRIS_LIB_DIR)
    if [[ -d "$SCRIPT_DIR/power_cleaner" ]]; then
        echo "$SCRIPT_DIR"
        return 0
    fi

    # 2. Override via environment variable (directory containing power_cleaner/)
    if [[ -n "${CHROME_POWER_PYTHONPATH:-}" && -d "$CHROME_POWER_PYTHONPATH/power_cleaner" ]]; then
        echo "$CHROME_POWER_PYTHONPATH"
        return 0
    fi

    return 1
}

PACKAGE_DIR="$(find_package_dir)"

if [[ -z "$PACKAGE_DIR" ]]; then
    echo "" >&2
    echo "  ${RED}⊘  power_cleaner package not found.${RESET}" >&2
    echo "" >&2
    echo "  ${DIM}Expected:${RESET}  $IRIS_LIB_DIR/power_cleaner/" >&2
    echo "" >&2
    echo "  ${CYAN}Re-run the installer:${RESET}" >&2
    echo "  ${DIM}bash <(curl -sL https://github.com/rhythwitty/bashiris/raw/main/install.sh)${RESET}" >&2
    echo "" >&2
    exit 1
fi

# Default root to standard ~/Documents/ChromePowerCache/chrome if not explicitly set
if [[ -z "${CHROME_POWER_ROOT:-}" && -d "$HOME/Documents/ChromePowerCache/chrome" ]]; then
    export CHROME_POWER_ROOT="$HOME/Documents/ChromePowerCache/chrome"
fi

export PYTHONPATH="$PACKAGE_DIR${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m power_cleaner "$@"
