#!/bin/bash

# ─────────────────────────────────────────────
#  uninstall.sh — iris uninstaller
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────

IRIS_BIN="/usr/local/bin/iris"
IRIS_LIB="/usr/local/lib/iris"

echo ""
echo "Uninstalling iris..."
echo ""

# Remove dispatcher
if [ -f "$IRIS_BIN" ]; then
    echo "  → Removing $IRIS_BIN"
    sudo rm -f "$IRIS_BIN"
else
    echo "  → $IRIS_BIN not found, skipping."
fi

# Remove lib dir
if [ -d "$IRIS_LIB" ]; then
    echo "  → Removing $IRIS_LIB"
    sudo rm -rf "$IRIS_LIB"
else
    echo "  → $IRIS_LIB not found, skipping."
fi

# Remove installed power_cleaner Python package (belt-and-suspenders if lib dir already gone)
if [ -d "$IRIS_LIB/power_cleaner" ]; then
    echo "  → Removing $IRIS_LIB/power_cleaner"
    sudo rm -rf "$IRIS_LIB/power_cleaner"
fi

echo ""
echo "✅  iris has been uninstalled."
echo ""
