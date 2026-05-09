#!/bin/bash

# ─────────────────────────────────────────────
#  verify-ssh — Verify GitHub SSH host aliases
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────
# IRIS_DESC: Verify GitHub SSH host aliases in ~/.ssh/config

CONFIG_FILE="${HOME}/.ssh/config"

show_help() {
    cat <<EOF
USAGE
    verify-ssh

DESCRIPTION
    Scans ~/.ssh/config for GitHub host aliases (Host github_*) and runs
    ssh -T git@<host> to verify that each SSH key and host alias are working.

EXAMPLES
    verify-ssh
EOF
}

add_host() {
    local candidate="$1"
    local existing

    for existing in "${HOSTS[@]}"; do
        if [[ "$existing" == "$candidate" ]]; then
            return
        fi
    done

    HOSTS+=("$candidate")
}

collect_hosts() {
    local line trimmed alias

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            ''|[[:space:]]*#)
                continue
                ;;
        esac

        trimmed="${line#${line%%[![:space:]]*}}"
        case "$trimmed" in
            Host\ *)
                for alias in $trimmed; do
                    case "$alias" in
                        Host)
                            continue
                            ;;
                        github_*)
                            add_host "$alias"
                            ;;
                    esac
                done
                ;;
        esac
    done < "$CONFIG_FILE"
}

verify_host() {
    local host="$1"
    local output
    local status

    echo "→ Verifying $host"
    output=$(ssh -T -o BatchMode=yes "git@$host" 2>&1)
    status=$?
    echo "$output"

    if echo "$output" | grep -q "successfully authenticated"; then
        echo "✓ $host verified"
        return 0
    fi

    if [[ $status -ne 0 ]]; then
        echo "✗ $host verification failed"
        return 1
    fi

    echo "✗ $host verification did not return the expected GitHub response"
    return 1
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌  SSH config not found: $CONFIG_FILE"
    exit 1
fi

HOSTS=()
collect_hosts

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "❌  No GitHub SSH hosts found in $CONFIG_FILE"
    exit 1
fi

echo "=== SSH VERIFICATION ==="
echo "Config file: $CONFIG_FILE"
echo "Hosts found: ${#HOSTS[@]}"
echo ""

FAILURES=0
for host in "${HOSTS[@]}"; do
    if ! verify_host "$host"; then
        FAILURES=1
    fi
    echo ""
done

if [[ $FAILURES -ne 0 ]]; then
    echo "❌  One or more GitHub SSH host verifications failed."
    exit 1
fi

echo "✅  All GitHub SSH hosts verified successfully."
