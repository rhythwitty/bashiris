#!/bin/bash

# ─────────────────────────────────────────────
#  setup-ssh — Generate SSH keys and configure GitHub access
#  https://github.com/rhythwitty/bashrepo
# ─────────────────────────────────────────────
# IRIS_DESC: Generate SSH keys and configure GitHub access

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SSH Key Setup Script ===${NC}\n"

# Prompt for email
read -p "Enter your email (e.g., abc@gmail.com): " EMAIL

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
ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/id_ed25519_${SSH_USER} -N "" -q

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH key pair generated successfully${NC}"
    echo -e "  Private key: ~/.ssh/id_ed25519_${SSH_USER}"
    echo -e "  Public key:  ~/.ssh/id_ed25519_${SSH_USER}.pub"
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

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh

# Append to SSH config
cat >> ~/.ssh/config << EOF

Host github_${SSH_USER}
  HostName github.com
  IdentityFile ~/.ssh/id_ed25519_${SSH_USER}
  User git
  IdentitiesOnly yes
EOF

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
cd ~/git/github_${SSH_USER}
echo -e "${GREEN}✓ Directory created and navigated to: $(pwd)${NC}"

echo -e "\n${BLUE}=== How to Clone Repositories ===${NC}"
echo -e "Replace ${YELLOW}github.com${NC} with ${YELLOW}github_${SSH_USER}${NC} in your clone commands:\n"
echo -e "${GREEN}Example:${NC}"
echo -e "  git clone git@github_${SSH_USER}:${SSH_USER}/hello-world.git"
echo -e "\n${YELLOW}💡 You are now in ~/git/github_${SSH_USER}/ - ready to clone!${NC}"
echo -e "${GREEN}Setup complete! 🎉${NC}\n"
