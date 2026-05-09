#!/bin/bash

# ─────────────────────────────────────────────
#  kill-port — Safely terminate process on port
# ─────────────────────────────────────────────
# IRIS_DESC: Safely terminate the process running on a given port

show_help() {
    cat <<EOF
USAGE
    kill-port <port_number>

DESCRIPTION
    Finds and terminates the process(es) listening on the given port.
    Attempts SIGTERM first, escalates to SIGKILL if the process survives.

EXAMPLES
    kill-port 3000
    kill-port 8080
EOF
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Check if port number provided
if [ -z "$1" ]; then
    echo "Usage: kill-port <port_number>"
    exit 1
fi

PORT="$1"

# Validate port is a number in a valid range
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "❌  Invalid port: $PORT. Must be a number between 1 and 65535."
    exit 1
fi

# Find PIDs using the port (lsof may return multiple for IPv4/IPv6)
PID_LIST=$(lsof -ti:"$PORT" 2>/dev/null)

if [ -z "$PID_LIST" ]; then
    echo "❌  No process found running on port $PORT"
    exit 1
fi

echo "⚠️  The following process(es) are occupying port $PORT:"
echo "   PID    COMMAND    USER"
while IFS= read -r PID; do
    PROCESS_INFO=$(ps -p "$PID" -o pid,comm,user= 2>/dev/null | tail -n 1)
    echo "   $PROCESS_INFO"
done <<< "$PID_LIST"
echo ""

read -p "Are you sure you want to kill these process(es)? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    while IFS= read -r PID; do
        kill "$PID" 2>/dev/null
        sleep 1
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null
            echo "✅  Process $PID on port $PORT force-killed (SIGKILL)."
        else
            echo "✅  Process $PID on port $PORT terminated (SIGTERM)."
        fi
    done <<< "$PID_LIST"
else
    echo "✅  Operation cancelled."
fi
