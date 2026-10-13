#!/bin/bash

# ─────────────────────────────────────────────
#  setup-ssh — Generate SSH keys and configure GitHub access
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Generate SSH keys and configure GitHub access

IRIS_SCRIPT_NAME="setup-ssh"

# ── Load shared library ───────────────────────────────────────────────────────
_COMMON="$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
[[ -f "$_COMMON" ]] || _COMMON="${IRIS_LIB_DIR:-/usr/local/lib/iris}/lib/common.sh"
# shellcheck source=scripts/lib/common.sh
source "$_COMMON" || {
    echo "⊘  Could not load iris common lib" >&2
    exit 1
}

# ── Defaults ──────────────────────────────────────────────────────────────────
OPT_EMAIL=""
OPT_USER=""
SKIP_KEYGEN=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "setup-ssh" "setup-ssh — help & usage"

    render_help_section "USAGE"
    echo "    setup-ssh ${DIM}[OPTIONS]${RESET}"
    echo "    iris setup-ssh ${DIM}[OPTIONS]${RESET}"
    echo ""

    render_help_section "DESCRIPTION"
    echo "    ${DIM}Generates an ED25519 SSH key pair and configures a GitHub host"
    echo "    alias in ~/.ssh/config. Prompts interactively for email and username"
    echo "    unless --email / --user are provided.${RESET}"
    echo ""

    render_help_section "OPTIONS"
    render_help_option "-h, --help" "Show this help message"
    render_help_option "--email <email>" "Email for SSH key comment (skips prompt)"
    render_help_option "--user <username>" "SSH username / GitHub handle (skips prompt)"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}setup-ssh${RESET}"
    echo "    ${DIM}setup-ssh --email you@example.com --user myhandle${RESET}"
    echo "    ${DIM}iris setup-ssh${RESET}"
    echo ""
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
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

# ── Email ─────────────────────────────────────────────────────────────────────
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

# ── Username ──────────────────────────────────────────────────────────────────
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

# ── Generate Key ──────────────────────────────────────────────────────────────
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

# ── Permissions ───────────────────────────────────────────────────────────────
echo ""
log_step "Setting secure permissions (600) on private key…"
chmod 600 "$key_path"
log_success "Permissions set."

# ── SSH Config ────────────────────────────────────────────────────────────────
CONFIG_FILE="$HOME/.ssh/config"
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
        printf '  HostName github.com\n'
        printf '  IdentityFile %s\n' "$key_path"
        printf '  User git\n'
        printf '  IdentitiesOnly yes\n'
    } >> "$CONFIG_FILE"
    log_success "SSH config updated."
fi

# ── Public Key Display ────────────────────────────────────────────────────────
echo ""
_thick_rule CYAN
printf "  ${BOLD}Your Public Key${RESET}\n"
_rule CYAN
log_detail "Copy this key and add it to your GitHub account:"
echo ""
cat "${key_path}.pub"
echo ""

# ── Next Steps ────────────────────────────────────────────────────────────────
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
