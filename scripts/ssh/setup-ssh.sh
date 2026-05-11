#!/bin/bash

# ─────────────────────────────────────────────
#  setup-ssh — Generate SSH keys and configure GitHub access
#  https://github.com/rhythwitty/bashiris
# ─────────────────────────────────────────────
# IRIS_DESC: Generate SSH keys and configure GitHub access

# ── Help ──────────────────────────────────────
show_help() {
    cat << EOF

$(tput bold)USAGE$(tput sgr0)
    setup-ssh [OPTIONS]

$(tput bold)DESCRIPTION$(tput sgr0)
    Generates an ED25519 SSH key pair and configures a GitHub host alias in ~/.ssh/config.

$(tput bold)OPTIONS$(tput sgr0)
    -h, --help      Show this help message

$(tput bold)EXAMPLES$(tput sgr0)
    setup-ssh
    iris setup-ssh

EOF
}

# ── Argument Parsing ──────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            echo "❌  Unknown option: $1"
            echo "    Run 'setup-ssh --help' for usage."
            exit 1
            ;;
    esac
done

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SSH Key Setup Script ===${NC}\n"

# Prompt for email
read -r -p "Enter your email (e.g., abc@gmail.com): " EMAIL

if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${YELLOW}⚠️  That does not look like a valid email address.${NC}"
    read -r -p "Use ${EMAIL}@gmail.com as the email for setup? [y/N]: " USE_GMAIL

    case "$USE_GMAIL" in
        [yY] | [yY][eE][sS])
            EMAIL="${EMAIL}@gmail.com"
            echo -e "${GREEN}✓ Using email: ${EMAIL}${NC}"
            ;;
        *)
            echo -e "${RED}✗ Invalid email input. Exiting without making changes.${NC}"
            exit 1
            ;;
    esac
fi

# Extract username from email (part before @)
DEFAULT_USER=$(echo "$EMAIL" | cut -d'@' -f1)

# Ask for confirmation or override
echo -e "\n${YELLOW}Default SSH username will be: ${DEFAULT_USER}${NC}"
read -r -p "Press Enter to use default, or type a custom username: " CUSTOM_USER

# Use custom username if provided, otherwise use default
if [ -z "$CUSTOM_USER" ]; then
    SSH_USER="$DEFAULT_USER"
    echo -e "${GREEN}✓ Using default SSH username: ${SSH_USER}${NC}"
else
    SSH_USER="$CUSTOM_USER"
    echo -e "${GREEN}✓ Using custom SSH username: ${SSH_USER}${NC}"
fi

# Generate SSH key
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
key_path="$HOME/.ssh/id_ed25519_${SSH_USER}"

if [[ -f "$key_path" ]]; then
    echo -e "\n${YELLOW}⚠️  SSH key already exists: ${key_path}${NC}"
    read -r -p "Overwrite existing key? [y/N]: " OVERWRITE_KEY
    case "$OVERWRITE_KEY" in
        [yY] | [yY][eE][sS])
            echo -e "${YELLOW}→ Overwriting existing key...${NC}"
            ;;
        *)
            echo -e "${GREEN}✓ Keeping existing key.${NC}"
            SKIP_KEYGEN=true
            ;;
    esac
fi

if [[ "$SKIP_KEYGEN" != true ]]; then
    echo -e "\n${YELLOW}→ Generating ED25519 SSH key pair...${NC}"
    if ssh-keygen -t ed25519 -C "$EMAIL" -f "$key_path" -N "" -q; then
        echo -e "${GREEN}✓ SSH key pair generated successfully${NC}"
        echo -e "  Private key: $key_path"
        echo -e "  Public key:  ${key_path}.pub"
    else
        echo -e "${RED}✗ Failed to generate SSH key${NC}"
        exit 1
    fi
fi

# Set proper permissions
echo -e "\n${YELLOW}→ Setting secure permissions (600) on private key...${NC}"
chmod 600 "$key_path"
echo -e "${GREEN}✓ Permissions set successfully${NC}"

# Create or update SSH config
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

if grep -q "Host github_${SSH_USER}" "$CONFIG_FILE"; then
    echo -e "\n${GREEN}✓ SSH config already contains host: github_${SSH_USER}. Skipping.${NC}"
else
    echo -e "\n${YELLOW}→ Adding configuration to ~/.ssh/config...${NC}"
    # Append to SSH config
    {
        printf '\n'
        printf 'Host github_%s\n' "$SSH_USER"
        printf '  HostName github.com\n'
        printf '  IdentityFile %s\n' "$key_path"
        printf '  User git\n'
        printf '  IdentitiesOnly yes\n'
    } >> "$CONFIG_FILE"
    echo -e "${GREEN}✓ SSH config updated successfully${NC}"
fi

# Display public key
echo -e "\n${BLUE}=== Your Public Key ===${NC}"
echo -e "${YELLOW}Copy this key and add it to your GitHub account:${NC}\n"
cat "${key_path}.pub"
echo ""

# Usage instructions
echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo -e "1. Copy the public key above"
echo -e "2. Go to GitHub → Settings → SSH and GPG keys → New SSH key"
echo -e "3. Paste your public key and save"
echo -e "\n${BLUE}=== Setting up Git Directory ===${NC}"

# Create git directories
echo -e "${YELLOW}→ Creating ~/git/github_${SSH_USER}/ directory...${NC}"
mkdir -p "$HOME/git/github_${SSH_USER}"
echo -e "${GREEN}✓ Directory created: ~/git/github_${SSH_USER}${NC}"
echo -e "${YELLOW}💡 Run: cd ~/git/github_${SSH_USER}${NC}"

echo -e "\n${BLUE}=== How to Clone Repositories ===${NC}"
echo -e "Replace ${YELLOW}github.com${NC} with ${YELLOW}github_${SSH_USER}${NC} in your clone commands:\n"
echo -e "${GREEN}Example:${NC}"
echo -e "  git clone git@github_${SSH_USER}:${SSH_USER}/hello-world.git"
echo -e "\n${YELLOW}💡 cd ~/git/github_${SSH_USER}/ — then clone your repos!${NC}"
echo -e "${GREEN}Setup complete! 🎉${NC}\n"
