#!/usr/bin/env bash

# ─────────────────────────────────────────────────────────────────────────────
#  scripts/lib/common.sh — Shared runtime helpers for iris scripts
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────────────────────────────────────
#
#  USAGE:
#    Source this file near the top of any iris script:
#
#      COMMON_LIB="$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#      [[ -f "$COMMON_LIB" ]] && source "$COMMON_LIB"
#
#    Or from the installed location (scripts source the installed copy):
#
#      IRIS_LIB_DIR="${IRIS_LIB_DIR:-/usr/local/lib/iris}"
#      [[ -f "$IRIS_LIB_DIR/lib/common.sh" ]] && source "$IRIS_LIB_DIR/lib/common.sh"
#
#  ENVIRONMENT VARIABLES:
#    NO_COLOR          If set (any value), disables all ANSI color output.
#    FORCE_YES         If "true", confirm_prompt() auto-confirms non-interactively.
#    IRIS_SCRIPT_NAME  Override the name shown in error/usage messages.
#
# ─────────────────────────────────────────────────────────────────────────────

# Guard against double-sourcing
[[ -n "${_IRIS_COMMON_LOADED:-}" ]] && return 0
_IRIS_COMMON_LOADED=1

# ── 1. Terminal Capability & Color Detection ──────────────────────────────────
#
#  Respects the NO_COLOR spec (https://no-color.org/):
#    - Disabled when stdout is not a TTY (pipes, CI logs, redirects)
#    - Disabled when the NO_COLOR environment variable is set
#    - Disabled when the tput command is unavailable
#
#  After sourcing, scripts may use: BOLD, DIM, RESET, CYAN, GREEN, YELLOW,
#  RED, GRAY, BLUE, MAGENTA, and the BRIGHT_* prefixed bold variants.

if [[ -t 1 ]] && command -v tput &> /dev/null && [[ -z "${NO_COLOR:-}" ]]; then
    BOLD=$(tput bold 2> /dev/null || true)
    DIM=$(tput dim 2> /dev/null || true)
    RESET=$(tput sgr0 2> /dev/null || true)
    CYAN=$(tput setaf 6 2> /dev/null || true)
    GREEN=$(tput setaf 2 2> /dev/null || true)
    YELLOW=$(tput setaf 3 2> /dev/null || true)
    RED=$(tput setaf 1 2> /dev/null || true)
    GRAY=$(tput setaf 8 2> /dev/null || true)
    BLUE=$(tput setaf 4 2> /dev/null || true)
    MAGENTA=$(tput setaf 5 2> /dev/null || true)
    # Bold+color variants for emphasis
    BRIGHT_GREEN="${BOLD}$(tput setaf 2 2> /dev/null || true)"
    BRIGHT_CYAN="${BOLD}$(tput setaf 6 2> /dev/null || true)"
    BRIGHT_RED="${BOLD}$(tput setaf 1 2> /dev/null || true)"
    BRIGHT_YELLOW="${BOLD}$(tput setaf 3 2> /dev/null || true)"
else
    BOLD="" DIM="" RESET=""
    CYAN="" GREEN="" YELLOW="" RED="" GRAY="" BLUE="" MAGENTA=""
    BRIGHT_GREEN="" BRIGHT_CYAN="" BRIGHT_RED="" BRIGHT_YELLOW=""
fi

# Export palette so sourcing scripts can use these variables without
# SC2034 "unused variable" warnings in common.sh itself.
# shellcheck disable=SC2034
export BOLD DIM RESET CYAN GREEN YELLOW RED GRAY BLUE MAGENTA
# shellcheck disable=SC2034
export BRIGHT_GREEN BRIGHT_CYAN BRIGHT_RED BRIGHT_YELLOW

# ── 2. Structured Logging ─────────────────────────────────────────────────────
#
#  Consistent glyphs and color across all scripts:
#    ℹ  info     — cyan    → stdout   (neutral progress / context)
#    ✓  success  — green   → stdout   (completed action)
#    ▸  step     — cyan    → stdout   (in-progress action step)
#       detail   — dim     → stdout   (indented supplementary info)
#    ⚠  warn     — yellow  → stderr   (non-fatal issue)
#    ⊘  error    — red     → stderr   (fatal, followed by exit)
#
#  Usage:
#    log_info    "Scanning 47 browsers…"
#    log_success "Cleanup complete. Freed ${BOLD}88.7 MB${RESET}."
#    log_step    "Generating SSH key pair…"
#    log_detail  "Key path: ~/.ssh/id_ed25519_myuser"
#    log_warn    "No process found on port $PORT"
#    log_err     "python3 is required but not found in PATH."

log_info() { printf "  ${CYAN}ℹ${RESET}  %b\n" "$*"; }
log_success() { printf "  ${GREEN}✓${RESET}  %b\n" "$*"; }
log_step() { printf "  ${CYAN}▸${RESET}  ${DIM}%b${RESET}\n" "$*"; }
log_detail() { printf "     ${DIM}%b${RESET}\n" "$*"; }
log_warn() { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*" >&2; }
log_err() { printf "\n  ${BRIGHT_RED}⊘${RESET}  ${BOLD}%b${RESET}\n\n" "$*" >&2; }

# ── 3. Rule / Section Dividers ────────────────────────────────────────────────
#
#  _rule [color_varname] [char] [width]
#    Prints a thin horizontal rule (─).
#    Pass the variable *name* (not value) for the color — e.g. "CYAN".
#    Defaults: CYAN, ─, 60
#
#  _thick_rule [color_varname] [char] [width]
#    Prints a double-line rule (═). Suitable for section headers.
#
#  Example:
#    _rule CYAN
#    echo "  Browsers"
#    _thick_rule CYAN

_rule() {
    local color="${!1:-$CYAN}"
    local char="${2:-─}"
    local width="${3:-60}"
    printf "%s%s%s\n" "$color" "$(printf "%${width}s" | tr ' ' "$char")" "$RESET"
}

_thick_rule() {
    local color="${!1:-$CYAN}"
    local char="${2:-═}"
    local width="${3:-60}"
    printf "%s%s%s\n" "$color" "$(printf "%${width}s" | tr ' ' "$char")" "$RESET"
}

# ── 4. Styled Help Banner & Sections ─────────────────────────────────────────
#
#  render_help_banner <title> <subtitle>
#    Renders a ╭─╮ bordered box with an ⚡ icon — the standard iris help header.
#
#  render_help_section <HEADING>
#    Prints a bold section heading (USAGE, OPTIONS, EXAMPLES, etc.).
#
#  render_help_option <flags> <description>
#    Prints one option row: cyan flags on the left, dim description on the right.
#    Flags column is 28 chars wide for alignment.
#
#  Example:
#    render_help_banner "kill-port" "kill-port — help & usage"
#    echo ""
#    render_help_section "USAGE"
#    echo "    kill-port <port>"
#    echo ""
#    render_help_section "OPTIONS"
#    render_help_option "-h, --help"    "Show this help message"
#    render_help_option "-y, --yes"     "Skip confirmation prompt"
#    render_help_option "--dry-run"     "Preview without killing"

render_help_banner() {
    local title="${1:-iris script}"
    local subtitle="${2:-help & usage}"
    local inner=42 # inner content width (between │ chars)

    printf "\n"
    printf "  ${BOLD}${CYAN}╭%s╮${RESET}\n" "$(printf '%*s' "$inner" '' | tr ' ' '─')"
    printf "  ${BOLD}${CYAN}│${RESET}  ${BOLD}⚡  %-*s${RESET}${BOLD}${CYAN}│${RESET}\n" \
        $((inner - 5)) "$title"
    printf "  ${BOLD}${CYAN}│${RESET}${DIM}     %-*s${RESET}${BOLD}${CYAN}│${RESET}\n" \
        $((inner - 5)) "$subtitle"
    printf "  ${BOLD}${CYAN}╰%s╯${RESET}\n" "$(printf '%*s' "$inner" '' | tr ' ' '─')"
    printf "\n"
}

render_help_section() {
    printf "${BOLD}%s${RESET}\n" "$1"
}

render_help_option() {
    local flags="$1"
    local description="$2"
    printf "    ${CYAN}%-28s${RESET}${DIM}%s${RESET}\n" "$flags" "$description"
}

# ── 5. Interactive Prompts & Confirmations ────────────────────────────────────
#
#  confirm_prompt <question>
#    Prints "? <question> [y/N]:" and reads a response.
#    Returns 0 if the user answered y/Y, 1 otherwise.
#    Skips the prompt and returns 0 when FORCE_YES=true.
#
#  typed_confirm_prompt <keyword>
#    Requires the user to type an exact keyword (e.g. "clean", "delete") to
#    proceed. Returns 0 on match, 1 otherwise. Useful for destructive actions.
#
#  press_enter_to_continue
#    A styled ↵ pause prompt.

confirm_prompt() {
    local question="${1:-Are you sure?}"

    if [[ "${FORCE_YES:-false}" == true ]]; then
        log_detail "Auto-confirmed via --yes / FORCE_YES."
        return 0
    fi

    local response
    printf "  ${YELLOW}?${RESET}  %b ${DIM}[y/N]${RESET}: " "$question"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

typed_confirm_prompt() {
    local keyword="${1:-confirm}"
    local response

    printf "  ${YELLOW}?${RESET}  Type ${BOLD}\"%s\"${RESET} to confirm: " "$keyword"
    read -r response
    [[ "$response" == "$keyword" ]]
}

press_enter_to_continue() {
    # SC2059: format string is intentional — DIM/RESET are tput sequences, not %s
    # shellcheck disable=SC2059
    printf "  ${DIM}↵  Press Enter to continue…${RESET} "
    read -r _
    printf "\n"
}

# ── 6. Dependency & Pre-flight Checks ────────────────────────────────────────
#
#  require_command <cmd> [install_hint]
#    Exits 1 if <cmd> is not in PATH. Prints a styled error with install hint.
#
#  require_platform <platform>
#    Exits 1 if not running on the given platform.
#    Valid values: macos, linux, windows
#
#  require_min_bash <major> [minor]
#    Exits 1 if the running Bash version is older than major.minor.
#    Defaults to 4.0 if minor is omitted.
#
#  Example:
#    require_command yt-dlp "Install with: brew install yt-dlp"
#    require_platform macos
#    require_min_bash 4 2

require_command() {
    local cmd="$1"
    local hint="${2:-Please install it to continue.}"

    if ! command -v "$cmd" &> /dev/null; then
        log_err "Missing required command: '${BOLD}${cmd}${RESET}'"
        log_detail "$hint" >&2
        exit "${IRIS_EXIT_FAIL:-1}"
    fi
}

require_platform() {
    local required="$1"
    local current
    current="$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/macos/')"

    if [[ "$current" != "$required" ]]; then
        local name="${IRIS_SCRIPT_NAME:-This script}"
        log_err "'${name}' is only supported on ${BOLD}${required}${RESET}."
        exit "${IRIS_EXIT_FAIL:-1}"
    fi
}

require_min_bash() {
    local required_major="${1:-4}"
    local required_minor="${2:-0}"
    local actual_major="${BASH_VERSINFO[0]}"
    local actual_minor="${BASH_VERSINFO[1]}"

    if ((actual_major < required_major)) ||
        ((actual_major == required_major && actual_minor < required_minor)); then
        log_err "Bash ${required_major}.${required_minor}+ required (running ${actual_major}.${actual_minor})."
        log_detail "On macOS, install a newer Bash with: ${BOLD}brew install bash${RESET}" >&2
        exit "${IRIS_EXIT_FAIL:-1}"
    fi
}

# ── 7. Argument Parsing Helpers ───────────────────────────────────────────────
#
#  parse_flag_value <flag_name> <next_arg>
#    Validates that the value following a flag is non-empty and is not itself
#    another flag (guards against "--flag --next-flag" where the value was
#    forgotten). Prints the validated value on stdout; exits 2 on error.
#
#  unknown_option <option> [script_name]
#    Prints a standardized "unknown option" error and exits 2 (usage error).
#
#  Example:
#    case "$1" in
#      --root)  ROOT="$(parse_flag_value --root "$2")"; shift 2 ;;
#      -*)      unknown_option "$1" ;;
#    esac

parse_flag_value() {
    local flag="$1"
    local value="$2"
    local script_name="${IRIS_SCRIPT_NAME:-script}"

    if [[ -z "$value" || "$value" == -* ]]; then
        log_err "Option '${BOLD}${flag}${RESET}' requires a value."
        log_detail "Run '${script_name} --help' for usage." >&2
        exit "${IRIS_EXIT_USAGE:-2}"
    fi

    printf '%s' "$value"
}

unknown_option() {
    local option="$1"
    local script_name="${2:-${IRIS_SCRIPT_NAME:-script}}"

    log_err "Unknown option: ${BOLD}${option}${RESET}"
    log_detail "Run '${script_name} --help' for usage." >&2
    exit "${IRIS_EXIT_USAGE:-2}"
}

# ── 8. Iris Library Path Resolution ──────────────────────────────────────────
#
#  resolve_iris_lib_dir
#    Outputs the iris library directory. Checks (in order):
#      1. $IRIS_LIB_DIR if already set in the environment
#      2. /usr/local/lib/iris   — default macOS/Linux installed path
#      3. ~/.local/lib/iris     — Windows (Git Bash / MSYS2 / Cygwin)
#
#  The result is suitable for use in sourcing lib/common.sh or locating
#  the power_cleaner package and other installed assets.

resolve_iris_lib_dir() {
    if [[ -n "${IRIS_LIB_DIR:-}" ]]; then
        printf '%s' "$IRIS_LIB_DIR"
        return 0
    fi

    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        printf '%s' "$HOME/.local/lib/iris"
    else
        printf '%s' "/usr/local/lib/iris"
    fi
}

# ── 9. Exit Code Conventions ──────────────────────────────────────────────────
#
#  Standardized exit codes across all iris scripts:
#    0  IRIS_EXIT_OK     — Success
#    1  IRIS_EXIT_FAIL   — Runtime/operational failure (command failed, file
#                          missing, unexpected state, etc.)
#    2  IRIS_EXIT_USAGE  — Usage error (bad/missing arguments)

# shellcheck disable=SC2034
readonly IRIS_EXIT_OK=0
# shellcheck disable=SC2034
readonly IRIS_EXIT_FAIL=1
# shellcheck disable=SC2034
readonly IRIS_EXIT_USAGE=2

# ─────────────────────────────────────────────────────────────────────────────
#  End of scripts/lib/common.sh
# ─────────────────────────────────────────────────────────────────────────────
