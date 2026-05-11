#!/bin/bash

# ─────────────────────────────────────────────
#  install.sh — iris installer
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────

REPO_URL="https://github.com/rhythwitty/bashiris/raw/main"
IRIS_BIN="/usr/local/bin/iris"
IRIS_LIB="/usr/local/lib/iris"
PLATFORM=$(uname -s)
sudo -v || exit 1

# Cross-platform scripts (macOS + Linux)
SCRIPTS_COMMON=(
    download-yt
    kill-port
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
sudo mkdir -p "$IRIS_LIB"

# Install dispatcher
echo "  → iris (dispatcher)"
curl -sL "$REPO_URL/iris" -o /tmp/iris_dispatcher
if [[ -f "/tmp/iris_dispatcher" ]]; then
    chmod +x /tmp/iris_dispatcher
    sudo mv /tmp/iris_dispatcher "$IRIS_BIN"
else
    echo "  ❌ Failed to download iris dispatcher"
    exit 1
fi

# Install release manifest for version lookup
echo "  → .release-please-manifest.json"
curl -sL "$REPO_URL/.release-please-manifest.json" -o /tmp/iris_release_manifest
if [[ -f "/tmp/iris_release_manifest" ]]; then
    sudo mv /tmp/iris_release_manifest "$IRIS_LIB/.release-please-manifest.json"
else
    echo "  ❌ Failed to download release manifest"
fi

# Install scripts
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    echo "  → $script_name"
    curl -sL "$REPO_URL/scripts/$script.sh" -o /tmp/"iris_${script_name}.sh"
    if [[ -f "/tmp/iris_${script_name}.sh" ]]; then
        chmod +x /tmp/"iris_${script_name}.sh"
        sudo mv /tmp/"iris_${script_name}.sh" "$IRIS_LIB/$script_name.sh"
    else
        echo "  ❌ Failed to download $script_name"
    fi
done

echo ""
echo "✅  Done! Run 'iris' to get started."
echo ""
