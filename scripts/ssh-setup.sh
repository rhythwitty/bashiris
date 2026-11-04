#!/bin/bash

# ─────────────────────────────────────────────
#  ssh-setup — Generate SSH keys and configure GitHub access
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Generate SSH keys and configure GitHub access

IRIS_SCRIPT_NAME="ssh-setup"

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
OPT_MIGRATE=false
SKIP_KEYGEN=false

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    render_help_banner "ssh-setup" "ssh-setup — help & usage"

    render_help_section "USAGE"
    echo "    ssh-setup ${DIM}[OPTIONS]${RESET}"
    echo "    iris ssh-setup ${DIM}[OPTIONS]${RESET}"
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
    render_help_option "--migrate" "Migrate legacy GitHub hosts in ~/.ssh/config to port 443"
    render_help_option "-y, --yes" "Skip confirmation prompts"
    echo ""

    render_help_section "EXAMPLES"
    echo "    ${DIM}ssh-setup${RESET}"
    echo "    ${DIM}ssh-setup --email you@example.com --user myhandle${RESET}"
    echo "    ${DIM}ssh-setup --migrate${RESET}"
    echo "    ${DIM}iris ssh-setup${RESET}"
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
        --migrate)
            OPT_MIGRATE=true
            shift
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

# ── Migration Helpers ─────────────────────────────────────────────────────────
count_legacy_hosts() {
    local config_file="$1"
    [[ -f "$config_file" ]] || {
        echo "0"
        return
    }
    awk '
    BEGIN { in_block=0; is_gh=0; old_hn=0; has_port=0; count=0 }
    /^[[:space:]]*Host[[:space:]]+/ {
        if (in_block && is_gh && (old_hn || !has_port)) count++
        in_block=1; is_gh=0; old_hn=0; has_port=0
        split($0, words)
        for (w in words) {
            if (words[w] ~ /^github_/ || words[w] == "github.com") {
                is_gh=1; break
            }
        }
        next
    }
    {
        if (in_block && is_gh) {
            if ($0 ~ /^[[:space:]]*HostName[[:space:]]+github\.com([[:space:]]|$)/) old_hn=1
            if ($0 ~ /^[[:space:]]*Port[[:space:]]+443([[:space:]]|$)/) has_port=1
        }
    }
    END {
        if (in_block && is_gh && (old_hn || !has_port)) count++
        print count
    }
    ' "$config_file"
}

get_legacy_hosts() {
    local config_file="$1"
    [[ -f "$config_file" ]] || return
    awk '
    BEGIN { in_block=0; is_gh=0; old_hn=0; has_port=0; host="" }
    /^[[:space:]]*Host[[:space:]]+/ {
        if (in_block && is_gh && (old_hn || !has_port)) print host
        in_block=1; is_gh=0; old_hn=0; has_port=0
        host=$0
        sub(/^[[:space:]]*Host[[:space:]]+/, "", host)
        split($0, words)
        for (w in words) {
            if (words[w] ~ /^github_/ || words[w] == "github.com") {
                is_gh=1; break
            }
        }
        next
    }
    {
        if (in_block && is_gh) {
            if ($0 ~ /^[[:space:]]*HostName[[:space:]]+github\.com([[:space:]]|$)/) old_hn=1
            if ($0 ~ /^[[:space:]]*Port[[:space:]]+443([[:space:]]|$)/) has_port=1
        }
    }
    END {
        if (in_block && is_gh && (old_hn || !has_port)) print host
    }
    ' "$config_file"
}

migrate_ssh_config() {
    local config_file="${1:-$CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        log_info "SSH config not found: ${BOLD}${config_file}${RESET}. Nothing to migrate."
        return 0
    fi

    local legacy_list count
    legacy_list="$(get_legacy_hosts "$config_file")"
    if [[ -z "$legacy_list" ]]; then
        count=0
    else
        count="$(echo "$legacy_list" | wc -l | tr -d ' ')"
    fi

    if [[ "$count" -eq 0 ]]; then
        log_success "All GitHub host entries in ${BOLD}${config_file}${RESET} already use port 443 (ssh.github.com)."
        return 0
    fi

    echo ""
    log_info "Found ${BOLD}${count}${RESET} GitHub host entry/entries using legacy port 22 configuration:"
    while IFS= read -r host_entry; do
        [[ -n "$host_entry" ]] && log_detail "${CYAN}•${RESET} Host ${BOLD}${host_entry}${RESET}"
    done <<< "$legacy_list"
    echo ""

    if ! confirm_prompt "Migrate ${count} GitHub host entry/entries to port 443 (ssh.github.com)?"; then
        log_info "Migration skipped."
        return 0
    fi

    local backup_file
    backup_file="${config_file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$config_file" "$backup_file"
    log_detail "Backup created: ${BOLD}${backup_file}${RESET}"

    local tmp_file
    tmp_file="$(mktemp "${config_file}.tmp.XXXXXX")"

    awk '
    BEGIN {
        in_block = 0
        is_github = 0
        block_len = 0
    }

    function flush_block(    i, line, has_port, has_identity, new_lines, n, indent, inserted_port) {
        if (block_len == 0) return

        if (!is_github) {
            for (i = 1; i <= block_len; i++) {
                print block[i]
            }
            block_len = 0
            return
        }

        has_port = 0
        has_identity = 0
        for (i = 1; i <= block_len; i++) {
            if (block[i] ~ /^[[:space:]]*Port[[:space:]]+/) has_port = 1
            if (block[i] ~ /^[[:space:]]*IdentityFile[[:space:]]+/) has_identity = 1
        }

        n = 0
        inserted_port = has_port
        for (i = 1; i <= block_len; i++) {
            line = block[i]
            if (line ~ /^[[:space:]]*HostName[[:space:]]+github\.com([[:space:]]|$)/) {
                match(line, /^[[:space:]]*/)
                indent = substr(line, RSTART, RLENGTH)
                line = indent "HostName ssh.github.com"
            }
            if (line ~ /^[[:space:]]*Port[[:space:]]+22([[:space:]]|$)/) {
                match(line, /^[[:space:]]*/)
                indent = substr(line, RSTART, RLENGTH)
                line = indent "Port 443"
                inserted_port = 1
            }
            n++
            new_lines[n] = line

            if (!inserted_port) {
                if (has_identity && line ~ /^[[:space:]]*IdentityFile[[:space:]]+/) {
                    match(line, /^[[:space:]]*/)
                    indent = substr(line, RSTART, RLENGTH)
                    n++
                    new_lines[n] = indent "Port 443"
                    inserted_port = 1
                } else if (!has_identity && line ~ /^[[:space:]]*HostName[[:space:]]+/) {
                    match(line, /^[[:space:]]*/)
                    indent = substr(line, RSTART, RLENGTH)
                    n++
                    new_lines[n] = indent "Port 443"
                    inserted_port = 1
                }
            }
        }

        for (i = 1; i <= n; i++) {
            print new_lines[i]
        }
        block_len = 0
    }

    /^[[:space:]]*Host[[:space:]]+/ {
        flush_block()
        in_block = 1
        is_github = 0

        split($0, words)
        for (w in words) {
            if (words[w] ~ /^github_/ || words[w] == "github.com") {
                is_github = 1
                break
            }
        }

        block_len = 1
        block[1] = $0
        next
    }

    {
        if (in_block) {
            block_len++
            block[block_len] = $0
        } else {
            print $0
        }
    }

    END {
        flush_block()
    }
    ' "$config_file" > "$tmp_file"

    chmod 600 "$tmp_file"
    mv "$tmp_file" "$config_file"
    chmod 600 "$config_file"

    log_success "Migrated ${BOLD}${count}${RESET} GitHub host entry/entries in ${BOLD}${config_file}${RESET}."
    log_detail "All entries updated to ${BOLD}HostName ssh.github.com${RESET} and ${BOLD}Port 443${RESET}."
}

if [[ "$OPT_MIGRATE" == true ]]; then
    echo ""
    _thick_rule CYAN
    printf "  ${BOLD}${CYAN}⚡  SSH Config Migration${RESET}\n"
    _rule CYAN
    echo ""
    migrate_ssh_config "$CONFIG_FILE"
    exit 0
fi

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

# Check for any legacy entries in ~/.ssh/config that need migration
legacy_count="$(count_legacy_hosts "$CONFIG_FILE")"
if [[ "$legacy_count" -gt 0 ]]; then
    echo ""
    log_info "Detected ${BOLD}${legacy_count}${RESET} legacy GitHub host entry/entries in ${BOLD}${CONFIG_FILE}${RESET} using port 22."
    if confirm_prompt "Migrate legacy entries to port 443 (ssh.github.com)?"; then
        migrate_ssh_config "$CONFIG_FILE"
    fi
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
