#!/bin/bash

# ─────────────────────────────────────────────
#  uninstall.sh — iris uninstaller
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────

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

echo ""
echo "Uninstalling iris..."
echo ""

# Remove dispatcher
if [ -f "$IRIS_BIN" ]; then
    echo "  → Removing $IRIS_BIN"
    if [[ "$IS_WINDOWS" == true ]]; then
        rm -f "$IRIS_BIN"
    else
        sudo rm -f "$IRIS_BIN"
    fi
else
    echo "  → $IRIS_BIN not found, skipping."
fi

# Remove lib dir
if [ -d "$IRIS_LIB" ]; then
    echo "  → Removing $IRIS_LIB"
    if [[ "$IS_WINDOWS" == true ]]; then
        rm -rf "$IRIS_LIB"
    else
        sudo rm -rf "$IRIS_LIB"
    fi
else
    echo "  → $IRIS_LIB not found, skipping."
fi

echo ""
echo "✅  iris has been uninstalled."
echo ""
