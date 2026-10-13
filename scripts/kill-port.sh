#!/bin/bash

# ─────────────────────────────────────────────
#  kill-port — Safely terminate process on port
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Safely terminate the process running on a given port

IRIS_SCRIPT_NAME="kill-port"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

# ── Defaults ──────────────────────────────────────────────────────────────────
PORT=""
DRY_RUN=false
FORCE_YES=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "kill-port" "kill-port — help & usage"

    render_help_section "USAGE"
    echo "    kill-port <port_number> ${DIM}[OPTIONS]${RESET}"
    echo "    iris kill-port <port_number> ${DIM}[OPTIONS]${RESET}"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Finds and terminates the process(es) listening on the given port."
    echo "    Sends SIGTERM first; escalates to SIGKILL if the process survives."
    echo "    Use --dry-run to preview matches without sending any signals.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-h, --help" "Show this help message"
    render_help_option "-y, --yes" "Skip confirmation prompt"
    render_help_option "--dry-run" "Show matching process(es) without killing"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}kill-port 3000${RESET}"
    echo "    ${DIM}kill-port 8080 --dry-run${RESET}"
    echo "    ${DIM}kill-port 5432 -y${RESET}"
    echo "    ${DIM}iris kill-port 8080${RESET}"
    echo ""
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        -y | --yes | --no-confirm)
            FORCE_YES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            unknown_option "$1"
            ;;
        *)
            PORT="$1"
            shift
            ;;
    esac
done

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$PORT" ]]; then
    log_err "No port number provided."
    log_detail "Run '${BOLD}kill-port --help${RESET}' for usage." >&2
    exit "$IRIS_EXIT_USAGE"
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((PORT < 1 || PORT > 65535)); then
    log_err "Invalid port: ${BOLD}${PORT}${RESET}. Must be a number between 1 and 65535."
    exit "$IRIS_EXIT_USAGE"
fi

require_command lsof "lsof is required (usually pre-installed on macOS/Linux)."

# ── Find Processes ────────────────────────────────────────────────────────────
PID_LIST=$(lsof -ti:"$PORT" 2> /dev/null)

if [[ -z "$PID_LIST" ]]; then
    log_warn "No process found running on port ${BOLD}${PORT}${RESET}."
    exit "$IRIS_EXIT_OK"
fi

# ── Display Matches ───────────────────────────────────────────────────────────
echo ""
_thick_rule CYAN
printf "  ${BOLD}Processes on port ${CYAN}%s${RESET}\n" "$PORT"
_rule CYAN
printf "  ${DIM}%-8s  %-24s  %s${RESET}\n" "PID" "COMMAND" "USER"
_rule CYAN

while IFS= read -r PID; do
    PROCESS_INFO=$(ps -p "$PID" -o pid=,comm=,user= 2> /dev/null | awk '{printf "%-8s  %-24s  %s", $1, $2, $3}')
    if [[ -n "$PROCESS_INFO" ]]; then
        printf "  ${YELLOW}%s${RESET}\n" "$PROCESS_INFO"
    fi
done <<< "$PID_LIST"

_rule CYAN
echo ""

# ── Dry Run ───────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
    log_info "${DIM}Dry run — no signals sent.${RESET}"
    exit "$IRIS_EXIT_OK"
fi

# ── Confirm & Kill ────────────────────────────────────────────────────────────
if ! confirm_prompt "Kill these process(es) on port ${BOLD}${PORT}${RESET}?"; then
    log_info "Operation cancelled."
    exit "$IRIS_EXIT_OK"
fi

echo ""
while IFS= read -r PID; do
    log_step "Sending SIGTERM to PID ${BOLD}${PID}${RESET}…"
    kill "$PID" 2> /dev/null
    sleep 1
    if kill -0 "$PID" 2> /dev/null; then
        log_step "Still running — escalating to SIGKILL…"
        kill -9 "$PID" 2> /dev/null
        log_success "PID ${BOLD}${PID}${RESET} on port ${BOLD}${PORT}${RESET} force-killed ${DIM}(SIGKILL)${RESET}."
    else
        log_success "PID ${BOLD}${PID}${RESET} on port ${BOLD}${PORT}${RESET} terminated ${DIM}(SIGTERM)${RESET}."
    fi
done <<< "$PID_LIST"
echo ""
