#!/bin/bash

# ─────────────────────────────────────────────
#  killport — Safely terminate process on port
# ─────────────────────────────────────────────

# Check if port number provided
if [ -z "$1" ]; then
    echo "Usage: killport <port_number>"
    exit 1
fi

PORT="$1"

# Find the PID using the port
# lsof is standard on macOS and most Linux distros
PID=$(lsof -ti:"$PORT" 2>/dev/null)

if [ -z "$PID" ]; then
    echo "❌ No process found running on port $PORT"
    exit 1
fi

# Get process details in a platform-agnostic way
# 'ps -p <pid> -o pid,comm,user' works on both macOS and Linux
PROCESS_INFO=$(ps -p "$PID" -o pid,comm,user= | tail -n 1)

echo "⚠️  The following process is occupying port $PORT:"
echo "   PID    COMMAND    USER"
echo "   $PROCESS_INFO"
echo ""

# Prompt for confirmation
read -p "Are you sure you want to kill this process? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    kill -9 "$PID"
    if [ $? -eq 0 ]; then
        echo "✅ Process $PID on port $PORT has been killed."
    else
        echo "❌ Failed to kill process $PID. You might need sudo."
    fi
else
    echo "✅ Operation cancelled."
fi
