#!/bin/bash

# ─────────────────────────────────────────────
#  install.sh — iris installer
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────

REPO_URL="https://github.com/rhythwitty/bashiris/raw/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM=$(uname -s)

# Detect if running on Windows (Git Bash, MSYS2, etc.)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    IS_WINDOWS=true
    IRIS_BIN="$HOME/.local/bin/iris"
    IRIS_LIB="$HOME/.local/lib/iris"
else
    IS_WINDOWS=false
    IRIS_BIN="/usr/local/bin/iris"
    IRIS_LIB="/usr/local/lib/iris"
fi

# Cross-platform scripts (macOS + Linux)
SCRIPTS_COMMON=(
    download-yt
    kill-port
    power-clean
    ssh/setup-ssh
    ssh/verify-ssh
)

# macOS-only scripts
SCRIPTS_MACOS=(
    check-power
)

# Build final script list for this platform
SCRIPTS=("${SCRIPTS_COMMON[@]}")
if [[ "$PLATFORM" == "Darwin" ]]; then
    SCRIPTS+=("${SCRIPTS_MACOS[@]}")
fi

echo ""
echo "Installing iris on $PLATFORM..."
echo ""

# Create lib dir
if [[ "$IS_WINDOWS" == true ]]; then
    mkdir -p "$IRIS_LIB"
else
    sudo mkdir -p "$IRIS_LIB"
fi

# Install dispatcher
echo "  → iris (dispatcher)"
if [[ -f "$SCRIPT_DIR/iris" ]]; then
    cp "$SCRIPT_DIR/iris" /tmp/iris_dispatcher
else
    curl -sL "$REPO_URL/iris" -o /tmp/iris_dispatcher
fi
if [[ -f "/tmp/iris_dispatcher" ]]; then
    chmod +x /tmp/iris_dispatcher
    if [[ "$IS_WINDOWS" == true ]]; then
        mv /tmp/iris_dispatcher "$IRIS_BIN"
    else
        sudo mv /tmp/iris_dispatcher "$IRIS_BIN"
    fi
else
    echo "  ❌ Failed to download iris dispatcher"
    exit 1
fi

# Install release manifest for version lookup
echo "  → .release-please-manifest.json"
if [[ -f "$SCRIPT_DIR/.release-please-manifest.json" ]]; then
    cp "$SCRIPT_DIR/.release-please-manifest.json" /tmp/iris_release_manifest
else
    curl -sL "$REPO_URL/.release-please-manifest.json" -o /tmp/iris_release_manifest
fi
if [[ -f "/tmp/iris_release_manifest" ]]; then
    if [[ "$IS_WINDOWS" == true ]]; then
        mv /tmp/iris_release_manifest "$IRIS_LIB/.release-please-manifest.json"
    else
        sudo mv /tmp/iris_release_manifest "$IRIS_LIB/.release-please-manifest.json"
    fi
else
    echo "  ❌ Failed to download release manifest"
fi

# Install scripts
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    echo "  → $script_name"
    if [[ -f "$SCRIPT_DIR/scripts/$script.sh" ]]; then
        cp "$SCRIPT_DIR/scripts/$script.sh" /tmp/"iris_${script_name}.sh"
    else
        curl -sL "$REPO_URL/scripts/$script.sh" -o /tmp/"iris_${script_name}.sh"
    fi
    if [[ -f "/tmp/iris_${script_name}.sh" ]]; then
        chmod +x /tmp/"iris_${script_name}.sh"
        if [[ "$IS_WINDOWS" == true ]]; then
            mv /tmp/"iris_${script_name}.sh" "$IRIS_LIB/$script_name.sh"
        else
            sudo mv /tmp/"iris_${script_name}.sh" "$IRIS_LIB/$script_name.sh"
        fi
    else
        echo "  ❌ Failed to download $script_name"
    fi
done

# Install power_cleaner Python package (lives beside power-clean.sh in $IRIS_LIB)
echo "  → power_cleaner (Python package)"
if [[ -d "$SCRIPT_DIR/scripts/power_cleaner" ]]; then
    if [[ "$IS_WINDOWS" == true ]]; then
        rm -rf "$IRIS_LIB/power_cleaner"
        cp -R "$SCRIPT_DIR/scripts/power_cleaner" "$IRIS_LIB/power_cleaner"
    else
        sudo rm -rf "$IRIS_LIB/power_cleaner"
        sudo cp -R "$SCRIPT_DIR/scripts/power_cleaner" "$IRIS_LIB/power_cleaner"
    fi
else
    echo "  ❌ power_cleaner package not found in repo — skipping"
fi

echo ""
echo "✅  Done! Run 'iris' to get started."
if [[ "$IS_WINDOWS" == true ]]; then
    echo "💡 Make sure ~/.local/bin is in your PATH"
fi
echo ""
