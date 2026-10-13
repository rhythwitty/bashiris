#!/bin/bash

# ─────────────────────────────────────────────
#  power-clean — ChromePower storage analyzer & cache cleaner
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Safe ChromePower storage analyzer and cache cleanup

if command -v tput &> /dev/null; then
    bold=$(tput bold)
    reset=$(tput sgr0)
else
    bold=""
    reset=""
fi

show_help() {
    cat << EOF

${bold}USAGE${reset}
    iris power-clean [OPTIONS]
    power-clean [OPTIONS]

${bold}DESCRIPTION${reset}
    Safe ChromePower storage analysis and cache cleanup tool.
    Accounts for all storage, protects active Chrome instances,
    and safely cleans regenerable caches without removing user data.

    Default root: ~/Documents/ChromePowerCache/chrome
    Override with: export CHROME_POWER_ROOT=/path/to/chrome

${bold}OPTIONS${reset}
    -h, --help              Show this help message
    --root <path>           ChromePower cache root path
    --dry-run               Show cleanup actions without deleting anything
    --clean-safe            Batch clean safe (regenerable) caches across all inactive profiles
    --clean-low-risk        Batch clean low-risk caches across all inactive profiles
    -y, --yes, --no-confirm Bypass interactive confirmation prompts
    --json                  Output full analysis as JSON to stdout and exit
    --version               Show version number

${bold}EXAMPLES${reset}
    iris power-clean
    iris power-clean --dry-run
    iris power-clean --clean-safe -y
    iris power-clean --clean-low-risk
    iris power-clean --root ~/Documents/ChromePowerCache/chrome

EOF
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if ! command -v python3 &> /dev/null; then
    echo "❌  python3 is required but not found in PATH."
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
    echo "❌  power_cleaner Python package not found."
    echo ""
    echo "Expected it in: $IRIS_LIB_DIR/power_cleaner/"
    echo ""
    echo "Re-run the installer: bash <(curl -sL https://github.com/rhythwitty/bashiris/raw/main/install.sh)"
    exit 1
fi

# Default root to standard ~/Documents/ChromePowerCache/chrome if not explicitly set
if [[ -z "${CHROME_POWER_ROOT:-}" && -d "$HOME/Documents/ChromePowerCache/chrome" ]]; then
    export CHROME_POWER_ROOT="$HOME/Documents/ChromePowerCache/chrome"
fi

export PYTHONPATH="$PACKAGE_DIR${PYTHONPATH:+:$PYTHONPATH}"
exec python3 -m power_cleaner "$@"
