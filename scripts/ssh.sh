#!/bin/bash

# ─────────────────────────────────────────────
#  ssh — Generate SSH keys, configure and verify GitHub SSH access
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Generate SSH keys, configure and verify GitHub SSH access

IRIS_SCRIPT_NAME="ssh"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

# ── Defaults ──────────────────────────────────────────────────────────────────
CONFIG_FILE="${IRIS_SSH_CONFIG:-$HOME/.ssh/config}"
OPT_EMAIL=""
OPT_USER=""
SKIP_KEYGEN=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "ssh" "ssh — help & usage"

    render_help_section "USAGE"
    echo "    iris ssh ${DIM}<subcommand> [OPTIONS]${RESET}"
    echo ""

    render_help_section "SUBCOMMANDS"
    printf "    %-20s %s\n" "setup" "Generate an SSH key pair and configure a GitHub host alias"
    printf "    %-20s %s\n" "verify" "Verify GitHub SSH host aliases in ~/.ssh/config"
    echo ""

    render_help_section "SETUP OPTIONS"
    render_help_option "-h, --help"        "Show this help message"
    render_help_option "--email <email>"   "Email for SSH key comment (skips prompt)"
    render_help_option "--user <username>" "SSH username / GitHub handle (skips prompt)"
    render_help_option "-y, --yes"         "Skip confirmation prompts"
    echo ""

    render_help_section "VERIFY OPTIONS"
    render_help_option "-h, --help" "Show this help message"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}iris ssh${RESET}"
    echo "    ${DIM}iris ssh setup${RESET}"
    echo "    ${DIM}iris ssh setup --email you@example.com --user myhandle${RESET}"
    echo "    ${DIM}iris ssh verify${RESET}"
    echo ""
}

# ── Interactive menu (bare `iris ssh`) ────────────────────────────────────────
show_menu() {
    echo ""
    _thick_rule CYAN
    printf "  ${BOLD}${CYAN}⚡  iris ssh${RESET}\n"
    _rule CYAN
    echo ""
    printf "  ${DIM}What would you like to do?${RESET}\n"
    echo ""
    printf "  ${CYAN}1${RESET}  Setup   — Generate SSH key & configure GitHub host alias\n"
    printf "  ${CYAN}2${RESET}  Verify  — Test GitHub SSH host aliases\n"
    printf "  ${CYAN}q${RESET}  Quit\n"
    echo ""
    printf "  ${CYAN}?${RESET}  Choice: "
    read -r MENU_CHOICE
    echo ""

    case "$MENU_CHOICE" in
        1 | setup)   run_setup   ;;
        2 | verify)  run_verify  ;;
        q | Q | quit | exit) exit 0 ;;
        *)
            log_err "Unknown choice: ${BOLD}${MENU_CHOICE}${RESET}"
            exit "$IRIS_EXIT_FAIL"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
#  SETUP
# ══════════════════════════════════════════════════════════════════════════════

run_setup() {
    # ── Parse setup-specific args ─────────────────────────────────────────────
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                show_help
                exit 0
                ;;
            --email)
                OPT_EMAIL="$(parse_flag_value --email "$2")"
                shift 2
                ;;
            --user)
                OPT_USER="$(parse_flag_value --user "$2")"
                shift 2
                ;;
            -y | --yes | --no-confirm)
                FORCE_YES=true
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

    require_command ssh-keygen "ssh-keygen is required (part of OpenSSH, usually pre-installed)."

    echo ""
    _thick_rule CYAN
    printf "  ${BOLD}${CYAN}⚡  SSH Key Setup${RESET}\n"
    _rule CYAN
    echo ""

    # ── Email ─────────────────────────────────────────────────────────────────
    if [[ -n "$OPT_EMAIL" ]]; then
        EMAIL="$OPT_EMAIL"
        log_info "Using email: ${BOLD}${EMAIL}${RESET}"
    else
        printf "  ${CYAN}?${RESET}  Enter your email ${DIM}(e.g. you@example.com)${RESET}: "
        read -r EMAIL

        if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            log_warn "That doesn't look like a valid email address."
            printf "  ${YELLOW}?${RESET}  Use ${BOLD}${EMAIL}@gmail.com${RESET} instead? ${DIM}[y/N]${RESET}: "
            read -r USE_GMAIL
            case "$USE_GMAIL" in
                [yY] | [yY][eE][sS])
                    EMAIL="${EMAIL}@gmail.com"
                    log_success "Using email: ${BOLD}${EMAIL}${RESET}"
                    ;;
                *)
                    log_err "Invalid email input. Exiting without changes."
                    exit "$IRIS_EXIT_FAIL"
                    ;;
            esac
        fi
    fi

    # ── Username ──────────────────────────────────────────────────────────────
    DEFAULT_USER=$(echo "$EMAIL" | cut -d'@' -f1)

    if [[ -n "$OPT_USER" ]]; then
        SSH_USER="$OPT_USER"
        log_info "Using username: ${BOLD}${SSH_USER}${RESET}"
    else
        echo ""
        log_detail "Default SSH username: ${BOLD}${DEFAULT_USER}${RESET}"
        printf "  ${CYAN}?${RESET}  Press Enter to use default, or type a custom username: "
        read -r CUSTOM_USER
        SSH_USER="${CUSTOM_USER:-$DEFAULT_USER}"
        log_success "Using username: ${BOLD}${SSH_USER}${RESET}"
    fi

    # ── Generate Key ──────────────────────────────────────────────────────────
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    key_path="$HOME/.ssh/id_ed25519_${SSH_USER}"

    if [[ -f "$key_path" ]]; then
        echo ""
        log_warn "SSH key already exists: ${BOLD}${key_path}${RESET}"
        if confirm_prompt "Overwrite existing key?"; then
            log_step "Overwriting existing key…"
        else
            log_success "Keeping existing key."
            SKIP_KEYGEN=true
        fi
    fi

    if [[ "$SKIP_KEYGEN" != true ]]; then
        echo ""
        log_step "Generating ED25519 SSH key pair…"
        if ssh-keygen -t ed25519 -C "$EMAIL" -f "$key_path" -N "" -q; then
            log_success "SSH key pair generated."
            log_detail "Private key: ${BOLD}${key_path}${RESET}"
            log_detail "Public key:  ${BOLD}${key_path}.pub${RESET}"
        else
            log_err "Failed to generate SSH key."
            exit "$IRIS_EXIT_FAIL"
        fi
    fi

    # ── Permissions ───────────────────────────────────────────────────────────
    echo ""
    log_step "Setting secure permissions (600) on private key…"
    chmod 600 "$key_path"
    log_success "Permissions set."

    # ── SSH Config ────────────────────────────────────────────────────────────
    touch "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"

    if grep -q "Host github_${SSH_USER}" "$CONFIG_FILE"; then
        echo ""
        log_success "SSH config already contains host: ${BOLD}github_${SSH_USER}${RESET}. Skipping."
    else
        echo ""
        log_step "Adding entry to ~/.ssh/config…"
        {
            printf '\n'
            printf 'Host github_%s\n' "$SSH_USER"
            printf '  HostName ssh.github.com\n'
            printf '  IdentityFile %s\n' "$key_path"
            printf '  Port 443\n'
            printf '  User git\n'
            printf '  IdentitiesOnly yes\n'
        } >> "$CONFIG_FILE"
        log_success "SSH config updated."
    fi

    # ── Public Key Display ────────────────────────────────────────────────────
    echo ""
    _thick_rule CYAN
    printf "  ${BOLD}Your Public Key${RESET}\n"
    _rule CYAN
    log_detail "Copy this key and add it to your GitHub account:"
    echo ""
    cat "${key_path}.pub"
    echo ""

    # ── Next Steps ────────────────────────────────────────────────────────────
    _thick_rule CYAN
    printf "  ${BOLD}Next Steps${RESET}\n"
    _rule CYAN
    echo ""
    printf "  ${CYAN}1.${RESET}  Copy the public key above\n"
    printf "  ${CYAN}2.${RESET}  Go to ${BOLD}GitHub → Settings → SSH and GPG keys → New SSH key${RESET}\n"
    printf "  ${CYAN}3.${RESET}  Paste your public key and save\n"
    echo ""

    log_step "Creating directory ~/git/github_${SSH_USER}/…"
    mkdir -p "$HOME/git/github_${SSH_USER}"
    log_success "Directory ready: ${BOLD}~/git/github_${SSH_USER}${RESET}"

    echo ""
    _rule CYAN
    printf "  ${BOLD}Clone repos using:${RESET}\n"
    echo ""
    printf "  ${DIM}git clone git@github_${SSH_USER}:${SSH_USER}/hello-world.git${RESET}\n"
    printf "  ${DIM}cd ~/git/github_${SSH_USER}/ — then clone your repos!${RESET}\n"
    echo ""
    log_success "Setup complete! 🎉"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  VERIFY
# ══════════════════════════════════════════════════════════════════════════════

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
        ok)               printf "${GREEN}PASS${RESET}" ;;
        permission_denied) printf "${RED}KEY FAIL${RESET}" ;;
        timeout)          printf "${YELLOW}TIMEOUT${RESET}" ;;
        dns)              printf "${YELLOW}DNS FAIL${RESET}" ;;
        network)          printf "${YELLOW}NETWORK${RESET}" ;;
        *)                printf "${RED}FAIL${RESET}" ;;
    esac
}

reason_text() {
    case "$1" in
        ok)               printf "Authenticated" ;;
        permission_denied) printf "Permission denied (publickey)" ;;
        timeout)          printf "Operation timed out" ;;
        dns)              printf "Hostname resolution failed" ;;
        network)          printf "Network connectivity failed" ;;
        *)                printf "Unexpected SSH response" ;;
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

run_verify() {
    # ── Parse verify-specific args ────────────────────────────────────────────
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

    # ── Pre-flight ────────────────────────────────────────────────────────────
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_err "SSH config not found: ${BOLD}${CONFIG_FILE}${RESET}"
        exit "$IRIS_EXIT_FAIL"
    fi

    collect_hosts

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        log_err "No GitHub SSH hosts found in ${BOLD}${CONFIG_FILE}${RESET}"
        log_detail "Run ${BOLD}iris ssh setup${RESET} to generate and register a host alias." >&2
        exit "$IRIS_EXIT_FAIL"
    fi

    # ── Verification Loop ─────────────────────────────────────────────────────
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

    # ── Results Table ─────────────────────────────────────────────────────────
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

    # ── Failed Hosts Detail ───────────────────────────────────────────────────
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
        printf "  ${CYAN}•${RESET}  Re-run ${BOLD}iris ssh setup${RESET} if the alias or key needs to be regenerated.\n"
        printf "  ${CYAN}•${RESET}  Check that the matching public key is uploaded to GitHub for each host.\n"
        printf "  ${CYAN}•${RESET}  Confirm the network can reach ${BOLD}github.com${RESET} if you see timeouts.\n"
        echo ""
        exit "$IRIS_EXIT_FAIL"
    fi

    log_success "All ${BOLD}${#HOSTS[@]}${RESET} GitHub SSH host(s) verified successfully."
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  DISPATCH
# ══════════════════════════════════════════════════════════════════════════════
SUBCOMMAND="${1:-}"
[[ -n "$SUBCOMMAND" ]] && shift

case "$SUBCOMMAND" in
    "" )
        show_menu
        ;;
    setup)
        run_setup "$@"
        ;;
    verify)
        run_verify "$@"
        ;;
    -h | --help)
        show_help
        ;;
    *)
        log_err "Unknown subcommand: ${BOLD}${SUBCOMMAND}${RESET}"
        echo ""
        show_help
        exit "$IRIS_EXIT_FAIL"
        ;;
esac
