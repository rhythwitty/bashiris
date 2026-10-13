#!/bin/bash

# ─────────────────────────────────────────────
#  check-power — Mac power configuration summary
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Show Mac power, sleep, and remote login configuration
# IRIS_PLATFORM: macos

IRIS_SCRIPT_NAME="check-power"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

NO_SUDO=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "check-power" "check-power — help & usage"

    render_help_section "USAGE"
    echo "    check-power ${DIM}[OPTIONS]${RESET}"
    echo "    iris check-power ${DIM}[OPTIONS]${RESET}"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Shows Mac power, sleep, and remote login configuration."
    echo "    Section 5 (remote login status) requires sudo by default."
    echo "    Pass --no-sudo to skip it without being prompted for a password.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-h, --help" "Show this help message"
    render_help_option "--no-sudo" "Skip remote login check (no sudo prompt)"
    echo ""
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        --no-sudo)
            NO_SUDO=true
            shift
            ;;
        -*)
            unknown_option "$1"
            ;;
        *)
            unknown_option "$1"
            ;;
    esac
done

require_platform macos

# ── Section helper ────────────────────────────────────────────────────────────
_section() {
    echo ""
    _rule CYAN
    printf "  ${BOLD}${CYAN}%s${RESET}\n" "$1"
    _rule CYAN
}

_kv_row() {
    local key="$1"
    local val="$2"
    printf "  ${DIM}%-30s${RESET}  %s\n" "$key" "$val"
}

# ── 1. Daily Schedule ─────────────────────────────────────────────────────────
_section "1  Daily Schedule"
pmset -g sched 2> /dev/null || log_detail "No scheduled events."

# ── 2. Hibernation & Auto-recovery ───────────────────────────────────────────
_section "2  Hibernation & Auto-recovery"
while IFS= read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    val=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
    _kv_row "$key" "$val"
done < <(pmset -g 2> /dev/null | grep -E "(hibernatemode|standbydelay|autorestart|highstandbythreshold)" | sort)

# ── 3. Sleep & Wake Settings ──────────────────────────────────────────────────
_section "3  Sleep & Wake Settings"
while IFS= read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    val=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
    _kv_row "$key" "$val"
done < <(pmset -g 2> /dev/null | grep -E "(sleep|displaysleep|disksleep|ttyskeepawake)" | sort)

# ── 4. Network & Remote Access ───────────────────────────────────────────────
_section "4  Network & Remote Access"
while IFS= read -r line; do
    key=$(echo "$line" | awk '{print $1}')
    val=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
    _kv_row "$key" "$val"
done < <(pmset -g 2> /dev/null | grep -E "(womp|powernap|tcpkeepalive|networkoversleep)" | sort)

# ── 5. Remote Login (SSH) Status ─────────────────────────────────────────────
_section "5  Remote Login (SSH) Status"
if [[ "$NO_SUDO" == true ]]; then
    log_info "${DIM}Skipped — pass without --no-sudo to check.${RESET}"
else
    log_detail "sudo required — you may be prompted for your password."
    sshStatus=$(sudo systemsetup -getremotelogin 2> /dev/null)
    if echo "$sshStatus" | grep -qi "on"; then
        _kv_row "Remote Login" "${GREEN}ENABLED${RESET}  ${DIM}(${sshStatus})${RESET}"
    else
        _kv_row "Remote Login" "${RED}DISABLED${RESET}  ${DIM}(${sshStatus})${RESET}"
    fi
fi

# ── 6. Current Power State ───────────────────────────────────────────────────
_section "6  Current Power State"
pmset -g ps 2> /dev/null | while IFS= read -r line; do
    log_detail "$line"
done || log_detail "AC Power"

echo ""
