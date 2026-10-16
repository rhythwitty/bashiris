#!/bin/bash

# ─────────────────────────────────────────────
#  verify-ssh — Verify GitHub SSH host aliases
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Verify GitHub SSH host aliases in ~/.ssh/config

IRIS_SCRIPT_NAME="verify-ssh"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

CONFIG_FILE="${HOME}/.ssh/config"

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "verify-ssh" "verify-ssh — help & usage"

    render_help_section "USAGE"
    echo "    verify-ssh ${DIM}[OPTIONS]${RESET}"
    echo "    iris verify-ssh ${DIM}[OPTIONS]${RESET}"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Scans ~/.ssh/config for GitHub host entries (Host github_* and"
    echo "    Host github.com) and runs ssh -T git@<host> to verify that each"
    echo "    SSH key and host alias work correctly.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-h, --help" "Show this help message"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}verify-ssh${RESET}"
    echo "    ${DIM}iris verify-ssh${RESET}"
    echo ""
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        -*)
            unknown_option "$1"
            ;;
        *)
            unknown_option "$1"
            ;;
    esac
done

# ── Host Collection ───────────────────────────────────────────────────────────
HOSTS=()

add_host() {
    local candidate="$1"
    for existing in "${HOSTS[@]}"; do
        [[ "$existing" == "$candidate" ]] && return
    done
    HOSTS+=("$candidate")
}

collect_hosts() {
    local line trimmed alias
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            '' | [[:space:]]*#) continue ;;
        esac
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "$trimmed" in
            Host\ *)
                for alias in $trimmed; do
                    case "$alias" in
                        Host) continue ;;
                        github_*) add_host "$alias" ;;
                        github.com) add_host "$alias" ;;
                    esac
                done
                ;;
        esac
    done < "$CONFIG_FILE"
}

# ── SSH Result Classifier ─────────────────────────────────────────────────────
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
        ok) printf "${GREEN}PASS${RESET}" ;;
        permission_denied) printf "${RED}KEY FAIL${RESET}" ;;
        timeout) printf "${YELLOW}TIMEOUT${RESET}" ;;
        dns) printf "${YELLOW}DNS FAIL${RESET}" ;;
        network) printf "${YELLOW}NETWORK${RESET}" ;;
        *) printf "${RED}FAIL${RESET}" ;;
    esac
}

reason_text() {
    case "$1" in
        ok) printf "Authenticated" ;;
        permission_denied) printf "Permission denied (publickey)" ;;
        timeout) printf "Operation timed out" ;;
        dns) printf "Hostname resolution failed" ;;
        network) printf "Network connectivity failed" ;;
        *) printf "Unexpected SSH response" ;;
    esac
}

# ── Host Verifier ─────────────────────────────────────────────────────────────
verify_host() {
    local host="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/iris_verify_ssh.XXXXXX)
    ssh -T -o BatchMode=yes -o ConnectTimeout=10 "git@${host}" > "$tmpfile" 2>&1
    local output
    output=$(cat "$tmpfile")
    rm -f "$tmpfile"
    classify_output "$output"
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_err "SSH config not found: ${BOLD}${CONFIG_FILE}${RESET}"
    exit "$IRIS_EXIT_FAIL"
fi

collect_hosts

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    log_err "No GitHub SSH hosts found in ${BOLD}${CONFIG_FILE}${RESET}"
    log_detail "Run ${BOLD}setup-ssh${RESET} to generate and register a host alias." >&2
    exit "$IRIS_EXIT_FAIL"
fi

# ── Verification Loop ─────────────────────────────────────────────────────────
echo ""
_thick_rule CYAN
printf "  ${BOLD}SSH Verification${RESET}  ${DIM}— %s${RESET}\n" "$CONFIG_FILE"
_rule CYAN
printf "  ${DIM}%-30s  %-12s  %s${RESET}\n" "Host" "Status" "Detail"
_rule CYAN

RESULTS_HOSTS=()
RESULTS_CODES=()
PASSED=0
FAILED=0

for host in "${HOSTS[@]}"; do
    log_step "Checking ${BOLD}${host}${RESET}…"
    classification=$(verify_host "$host")
    RESULTS_HOSTS+=("$host")
    RESULTS_CODES+=("$classification")
    if [[ "$classification" == "ok" ]]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

# ── Results Table ─────────────────────────────────────────────────────────────
_rule CYAN
for i in "${!RESULTS_HOSTS[@]}"; do
    host="${RESULTS_HOSTS[$i]}"
    cls="${RESULTS_CODES[$i]}"
    printf "  %-30s  %-20s  %s\n" "$host" "$(status_label "$cls")" "$(reason_text "$cls")"
done
_rule CYAN
printf "  ${BOLD}%d${RESET} total  •  ${GREEN}%d passed${RESET}  •  ${RED}%d failed${RESET}\n" \
    "${#HOSTS[@]}" "$PASSED" "$FAILED"
_thick_rule CYAN
echo ""

# ── Failed Hosts Detail ───────────────────────────────────────────────────────
if [[ $FAILED -ne 0 ]]; then
    render_help_section "Failed hosts"
    echo ""
    for i in "${!RESULTS_HOSTS[@]}"; do
        cls="${RESULTS_CODES[$i]}"
        [[ "$cls" == "ok" ]] && continue
        host="${RESULTS_HOSTS[$i]}"
        printf "  ${RED}•${RESET}  ${BOLD}%s${RESET} — %s\n" "$host" "$(reason_text "$cls")"
    done
    echo ""
    render_help_section "Next steps"
    echo ""
    printf "  ${CYAN}•${RESET}  Re-run ${BOLD}iris setup-ssh${RESET} if the alias or key needs to be regenerated.\n"
    printf "  ${CYAN}•${RESET}  Check that the matching public key is uploaded to GitHub for each host.\n"
    printf "  ${CYAN}•${RESET}  Confirm the network can reach ${BOLD}github.com${RESET} if you see timeouts.\n"
    echo ""
    exit "$IRIS_EXIT_FAIL"
fi

log_success "All ${BOLD}${#HOSTS[@]}${RESET} GitHub SSH host(s) verified successfully."
echo ""
