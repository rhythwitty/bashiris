#!/bin/bash

# ─────────────────────────────────────────────
#  setup-ssh — Generate SSH keys and configure GitHub access
#  https://github.com/rhythwitty/bashrepo
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
read -p "Enter your email (e.g., abc@gmail.com): " EMAIL

if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo -e "${YELLOW}⚠️  That does not look like a valid email address.${NC}"
    read -p "Use ${EMAIL}@gmail.com as the email for setup? [y/N]: " USE_GMAIL

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
read -p "Press Enter to use default, or type a custom username: " CUSTOM_USER

# Use custom username if provided, otherwise use default
if [ -z "$CUSTOM_USER" ]; then
    SSH_USER="$DEFAULT_USER"
    echo -e "${GREEN}✓ Using default SSH username: ${SSH_USER}${NC}"
else
    SSH_USER="$CUSTOM_USER"
    echo -e "${GREEN}✓ Using custom SSH username: ${SSH_USER}${NC}"
fi

# Generate SSH key
echo -e "\n${YELLOW}→ Generating ED25519 SSH key pair...${NC}"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519_${SSH_USER} -N "" -q

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH key pair generated successfully${NC}"
    echo -e "  Private key: ~/.ssh/id_ed25519_${SSH_USER}"
    echo -e "  Public key:  ~/.ssh/id_ed25519_${SSH_USER}.pub"
else
    echo -e "${RED}✗ Failed to generate SSH key${NC}"
    exit 1
fi

# Set proper permissions
echo -e "\n${YELLOW}→ Setting secure permissions (600) on private key...${NC}"
chmod 600 ~/.ssh/id_ed25519_${SSH_USER}
echo -e "${GREEN}✓ Permissions set successfully${NC}"

# Create or update SSH config
echo -e "\n${YELLOW}→ Adding configuration to ~/.ssh/config...${NC}"

# Append to SSH config
cat >> ~/.ssh/config << EOF

Host github_${SSH_USER}
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519_${SSH_USER}
  User git
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
echo -e "${GREEN}✓ SSH config updated successfully${NC}"

# Display public key
echo -e "\n${BLUE}=== Your Public Key ===${NC}"
echo -e "${YELLOW}Copy this key and add it to your GitHub account:${NC}\n"
cat ~/.ssh/id_ed25519_${SSH_USER}.pub
echo ""

# Usage instructions
echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo -e "1. Copy the public key above"
echo -e "2. Go to GitHub → Settings → SSH and GPG keys → New SSH key"
echo -e "3. Paste your public key and save"
echo -e "\n${BLUE}=== Setting up Git Directory ===${NC}"

# Create git directories
echo -e "${YELLOW}→ Creating ~/git/github_${SSH_USER}/ directory...${NC}"
mkdir -p ~/git/github_${SSH_USER}
echo -e "${GREEN}✓ Directory created: ~/git/github_${SSH_USER}${NC}"
echo -e "${YELLOW}💡 Run: cd ~/git/github_${SSH_USER}${NC}"

echo -e "\n${BLUE}=== How to Clone Repositories ===${NC}"
echo -e "Replace ${YELLOW}github.com${NC} with ${YELLOW}github_${SSH_USER}${NC} in your clone commands:\n"
echo -e "${GREEN}Example:${NC}"
echo -e "  git clone git@github_${SSH_USER}:${SSH_USER}/hello-world.git"
echo -e "\n${YELLOW}💡 cd ~/git/github_${SSH_USER}/ — then clone your repos!${NC}"
echo -e "${GREEN}Setup complete! 🎉${NC}\n"
