#!/bin/bash

# ─────────────────────────────────────────────
#  verify-ssh — Verify GitHub SSH host aliases
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Verify GitHub SSH host aliases in ~/.ssh/config

CONFIG_FILE="${HOME}/.ssh/config"

if command -v tput &> /dev/null; then
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    CYAN=$(tput setaf 6)
else
    BOLD=""
    RESET=""
    GREEN=""
    YELLOW=""
    RED=""
    CYAN=""
fi

summary_border() {
    printf '%s\n' "${CYAN}────────────────────────────────────────────────────────${RESET}"
}

show_help() {
    cat << EOF

$(tput bold)USAGE$(tput sgr0)
    verify-ssh [OPTIONS]

$(tput bold)DESCRIPTION$(tput sgr0)
    Scans ~/.ssh/config for GitHub host entries (Host github_* and Host github.com)
    and runs ssh -T git@<host> to verify that each SSH key and host alias work.

$(tput bold)OPTIONS$(tput sgr0)
    -h, --help      Show this help message

$(tput bold)EXAMPLES$(tput sgr0)
    verify-ssh
    iris verify-ssh

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            echo "❌  Unknown option: $1"
            echo "    Run 'verify-ssh --help' for usage."
            exit 1
            ;;
    esac
done

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

classify_output() {
    local output="$1"

    if echo "$output" | grep -qi 'successfully authenticated'; then
        echo "ok"
    elif echo "$output" | grep -qi 'permission denied (publickey)'; then
        echo "permission_denied"
    elif echo "$output" | grep -qi 'operation timed out'; then
        echo "timeout"
    elif echo "$output" | grep -qi 'could not resolve hostname\|name or service not known\|temporary failure in name resolution'; then
        echo "dns"
    elif echo "$output" | grep -qi 'connection timed out\|no route to host\|network is unreachable'; then
        echo "network"
    else
        echo "unknown"
    fi
}

status_label() {
    case "$1" in
        ok)
            printf '%sPASS%s' "$GREEN" "$RESET"
            ;;
        permission_denied)
            printf '%sKEY FAIL%s' "$RED" "$RESET"
            ;;
        timeout)
            printf '%sTIMEOUT%s' "$YELLOW" "$RESET"
            ;;
        dns)
            printf '%sDNS FAIL%s' "$YELLOW" "$RESET"
            ;;
        network)
            printf '%sNETWORK%s' "$YELLOW" "$RESET"
            ;;
        *)
            printf '%sFAIL%s' "$RED" "$RESET"
            ;;
    esac
}

reason_text() {
    case "$1" in
        ok)
            printf 'Authenticated'
            ;;
        permission_denied)
            printf 'Permission denied (publickey)'
            ;;
        timeout)
            printf 'Operation timed out'
            ;;
        dns)
            printf 'Hostname resolution failed'
            ;;
        network)
            printf 'Network connectivity failed'
            ;;
        *)
            printf 'Unexpected SSH response'
            ;;
    esac
}

collect_hosts() {
    local line trimmed alias

    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            '' | [[:space:]]*#)
                continue
                ;;
        esac

        trimmed="${line#"${line%%[![:space:]]*}"}"
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
                        github.com)
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
    local status
    local classification

    ssh -T -o BatchMode=yes -o ConnectTimeout=10 "git@$host" > /tmp/iris_verify_ssh.$$ 2>&1
    status=$?
    output=$(cat /tmp/iris_verify_ssh.$$)
    rm -f /tmp/iris_verify_ssh.$$

    classification=$(classify_output "$output")

    RESULTS_HOSTS+=("$host")
    RESULTS_CODES+=("$classification")

    if [[ "$classification" == "ok" ]]; then
        PASSED=$((PASSED + 1))
        return 0
    fi

    if [[ $status -ne 0 ]]; then
        FAILED=$((FAILED + 1))
        return 1
    fi

    FAILED=$((FAILED + 1))
    return 1
}

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

RESULTS_HOSTS=()
RESULTS_CODES=()
PASSED=0
FAILED=0

echo "${BOLD}SSH verification${RESET}"
echo "Config: $CONFIG_FILE"
echo "Hosts: ${#HOSTS[@]}"
summary_border
printf "%-28s %-12s %s\n" "Host" "Status" "Summary"
summary_border

for host in "${HOSTS[@]}"; do
    verify_host "$host"
done

for i in "${!RESULTS_HOSTS[@]}"; do
    host="${RESULTS_HOSTS[$i]}"
    classification="${RESULTS_CODES[$i]}"
    printf '%-28s %s  %s\n' "$host" "$(status_label "$classification")" "$(reason_text "$classification")"
done

summary_border
printf 'Summary: %d total • %s%d%s passed • %s%d%s failed\n' "${#HOSTS[@]}" "$GREEN" "$PASSED" "$RESET" "$RED" "$FAILED" "$RESET"

if [[ $FAILED -ne 0 ]]; then
    echo ""
    echo "${BOLD}Failed hosts${RESET}"
    for i in "${!RESULTS_HOSTS[@]}"; do
        classification="${RESULTS_CODES[$i]}"
        if [[ "$classification" == "ok" ]]; then
            continue
        fi

        host="${RESULTS_HOSTS[$i]}"
        printf '• %s — %s\n' "$host" "$(reason_text "$classification")"
    done

    echo ""
    echo "${BOLD}Next steps${RESET}"
    cat << 'EOF'
- Re-run `iris setup-ssh` if the alias or key needs to be regenerated.
- Check that the matching public key is uploaded to GitHub for each host.
- Confirm the network can reach `github.com` if you see timeouts.
EOF
    exit 1
fi

echo ""
echo "${GREEN}✅  All GitHub SSH hosts verified successfully.${RESET}"
