#!/bin/bash

# ─────────────────────────────────────────────
#  install.sh — iris installer
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────

REPO_URL="https://github.com/rhythwitty/bashrepo/raw/main"
IRIS_BIN="/usr/local/bin/iris"
IRIS_LIB="/usr/local/lib/iris"
PLATFORM=$(uname -s)

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
chmod +x /tmp/iris_dispatcher
sudo mv /tmp/iris_dispatcher "$IRIS_BIN"

# Install release manifest for version lookup
echo "  → .release-please-manifest.json"
curl -sL "$REPO_URL/.release-please-manifest.json" -o /tmp/iris_release_manifest
sudo mv /tmp/iris_release_manifest "$IRIS_LIB/.release-please-manifest.json"

# Install scripts
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    echo "  → $script_name"
    curl -sL "$REPO_URL/scripts/$script.sh" -o /tmp/"iris_${script_name}.sh"
    chmod +x /tmp/"iris_${script_name}.sh"
    sudo mv /tmp/"iris_${script_name}.sh" "$IRIS_LIB/$script_name.sh"
done

echo ""
echo "✅  Done! Run 'iris' to get started."
echo ""
