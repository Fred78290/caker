#!/bin/bash

# Sparkle signature key generation script
# Usage: ./Scripts/sparkle-generate-keys.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
KEYS_DIR="${PROJECT_ROOT}/.sparkle"
PATH="${HOMEBREW_PREFIX}/Caskroom/sparkle/2.9.0/bin:${PATH}" # Ensure scripts are in PATH for subcommands

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Sparkle production configuration for Caker${NC}"
echo

# Create keys folder (ignored by git)
mkdir -p "${KEYS_DIR}"

# Check if Sparkle is installed
if ! command -v generate_keys &> /dev/null; then
    echo -e "${YELLOW}⚠️  Sparkle is not installed via Homebrew${NC}"
    echo "Installing Sparkle..."
    
    if command -v brew &> /dev/null; then
        brew install sparkle
    else
        echo -e "${RED}❌ Homebrew required to install Sparkle${NC}"
        echo "Install Homebrew or download Sparkle manually from:"
        echo "https://sparkle-project.org/downloads"
        exit 1
    fi
fi

# Check if keys already exist
if [[ -f "${KEYS_DIR}/sparkle_private_key.pem" && -f "${KEYS_DIR}/sparkle_public_key.pem" ]]; then
    echo -e "${YELLOW}⚠️  Sparkle keys already exist${NC}"
    echo "Keys found in: ${KEYS_DIR}"
    echo
    read -p "Do you want to regenerate them? (y/N): " -n 1 -r
    echo
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Using existing keys${NC}"
        echo
        echo -e "${YELLOW}Current public key:${NC}"
        cat "${KEYS_DIR}/sparkle_public_key.pem"
        exit 0
    fi
    
    echo -e "${YELLOW}🔄 Regenerating keys...${NC}"
    rm -f "${KEYS_DIR}/sparkle_private_key.pem" "${KEYS_DIR}/sparkle_public_key.pem"
    security delete-generic-password -l "Private key for signing Sparkle updates" 2>/dev/null || true
fi

# Generate new keys
echo -e "${GREEN}🔑 Generating new Ed25519 keys...${NC}"
cd "${KEYS_DIR}"

# Use Sparkle tool to generate keys
$(generate_keys | grep <string>|sed -E 's/.*<string>(.*)<\/string>.*/\1/') > sparkle_public_key.pem
generate_keys -x sparkle_private_key.pem

# Check that keys were generated
if [[ ! -f "sparkle_private_key.pem" || ! -f "sparkle_public_key.pem" ]]; then
    echo -e "${RED}❌ Error generating keys${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Keys generated successfully${NC}"
echo

# Display public key
echo -e "${YELLOW}📋 Public key to use in Info.plist:${NC}"
echo "$(cat sparkle_public_key.pem)"
echo

# Automatically update Info.plist
PUBLIC_KEY="$(cat sparkle_public_key.pem)"

echo
echo -e "${GREEN}🔒 Security configuration${NC}"
echo "• Private key: ${KEYS_DIR}/sparkle_private_key.pem"
echo "• Public key: ${KEYS_DIR}/sparkle_public_key.pem"
echo
echo -e "${RED}⚠️  IMPORTANT: Never commit the private key!${NC}"
echo "The .sparkle folder is ignored by git by default."
echo

echo -e "${GREEN}✅ Sparkle configuration completed${NC}"
echo "Next steps:"
echo "1. Test compilation: swift build"
echo "2. Configure signing process in your build scripts"
echo "3. Create your first signed release"