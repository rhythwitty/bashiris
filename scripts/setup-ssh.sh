#!/bin/bash

# ─────────────────────────────────────────────
#  setup-ssh — Legacy wrapper for SSH key setup
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/ssh/setup-ssh.sh" "$@"
