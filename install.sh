#!/bin/bash

# ─────────────────────────────────────────────
#  install.sh — iris installer
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────

REPO_URL="https://github.com/rhythwitty/bashrepo/raw/main"
IRIS_BIN="/usr/local/bin/iris"
IRIS_LIB="/usr/local/lib/iris"

SCRIPTS=(
    check-power
    download-yt
    kill-port
    setup-ssh
)

echo ""
echo "Installing iris..."
echo ""

# Create lib dir
sudo mkdir -p "$IRIS_LIB"

# Install dispatcher
echo "  → iris (dispatcher)"
curl -sL "$REPO_URL/iris" -o /tmp/iris_dispatcher
chmod +x /tmp/iris_dispatcher
sudo mv /tmp/iris_dispatcher "$IRIS_BIN"

# Install scripts
for script in "${SCRIPTS[@]}"; do
    echo "  → $script"
    curl -sL "$REPO_URL/scripts/$script.sh" -o /tmp/"iris_${script}.sh"
    chmod +x /tmp/"iris_${script}.sh"
    sudo mv /tmp/"iris_${script}.sh" "$IRIS_LIB/$script.sh"
done

echo ""
echo "✅  Done! Run 'iris' to get started."
echo ""
