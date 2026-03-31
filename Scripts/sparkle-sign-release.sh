#!/bin/bash

# Sparkle release signing and publishing script
# Usage: ./Scripts/sparkle-sign-release.sh <version> <release-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KEYS_DIR="${PROJECT_ROOT}/.sparkle"
RELEASES_DIR="${PROJECT_ROOT}/releases"
APPCAST_DIR="${PROJECT_ROOT}/docs/appcast"
PATH="${HOMEBREW_PREFIX}/Caskroom/sparkle/2.9.0/bin:${PATH}" # Ensure scripts are in PATH for subcommands

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameter validation
if [[ $# -lt 2 ]]; then
    echo -e "${RED}❌ Usage: $0 <version> <release-file>${NC}"
    echo "Example: $0 1.2.3 /path/to/Caker-1.2.3.dmg"
    exit 1
fi

VERSION="$1"
RELEASE_FILE="$2"

echo -e "${GREEN}🚀 Sparkle release signing${NC}"
echo "Version: ${VERSION}"
echo "File: ${RELEASE_FILE}"
echo

# Prerequisites validation
if [[ ! -f "${RELEASE_FILE}" ]]; then
    echo -e "${RED}❌ Release file not found: ${RELEASE_FILE}${NC}"
    exit 1
fi

if [[ ! -f "${KEYS_DIR}/sparkle_private_key.pem" ]]; then
    echo -e "${RED}❌ Sparkle private key not found${NC}"
    echo "Run first: ./Scripts/sparkle-generate-keys.sh"
    exit 1
fi

if ! command -v sign_update &> /dev/null; then
    echo -e "${RED}❌ Tool 'sign_update' not found${NC}"
    echo "Install Sparkle via Homebrew: brew install sparkle"
    exit 1
fi

# Create necessary folders
mkdir -p "${RELEASES_DIR}"
mkdir -p "${APPCAST_DIR}"

# Copy release file
RELEASE_FILENAME="$(basename "${RELEASE_FILE}")"
RELEASE_DEST="${RELEASES_DIR}/${RELEASE_FILENAME}"

if [[ "${RELEASE_FILE}" != "${RELEASE_DEST}" ]]; then
    echo -e "${GREEN}📁 Copying release file...${NC}"
    cp "${RELEASE_FILE}" "${RELEASE_DEST}"
fi

# Get file size
FILE_SIZE=$(stat -f%z "${RELEASE_DEST}")

# Sign file
echo -e "${GREEN}🔐 Signing file with Sparkle...${NC}"
SIGNATURE=$(sign_update "${RELEASE_DEST}" "${KEYS_DIR}/sparkle_private_key.pem")

echo -e "${GREEN}✅ Signature generated:${NC} ${SIGNATURE}"
echo

# Generate release information
RELEASE_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
RELEASE_NOTES_FILE="${APPCAST_DIR}/release-notes-${VERSION}.html"

# Create default release notes if they don't exist
if [[ ! -f "${RELEASE_NOTES_FILE}" ]]; then
    echo -e "${YELLOW}📝 Creating default release notes...${NC}"
    cat > "${RELEASE_NOTES_FILE}" << EOF
<h2>Caker ${VERSION}</h2>
<p>New version of Caker with improvements and bug fixes.</p>

<h3>What's new</h3>
<ul>
    <li>Performance improvements</li>
    <li>Minor bug fixes</li>
</ul>

<h3>Technical information</h3>
<ul>
    <li>macOS 15+ compatibility</li>
    <li>Automatic updates via Sparkle</li>
</ul>
EOF
    echo -e "${YELLOW}⚠️  Default release notes created${NC}"
    echo "Edit the file: ${RELEASE_NOTES_FILE}"
fi

# Update or create appcast
APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
TEMP_ITEM=$(mktemp)

# Create new item
cat > "${TEMP_ITEM}" << EOF
        <item>
            <title>Caker ${VERSION}</title>
            <description><![CDATA[$(cat "${RELEASE_NOTES_FILE}")]]></description>
            <pubDate>${RELEASE_DATE}</pubDate>
            <enclosure url="https://github.com/Fred78290/caker/releases/download/v${VERSION}/${RELEASE_FILENAME}"
                       sparkle:version="${VERSION}"
                       sparkle:shortVersionString="${VERSION}"
                       length="${FILE_SIZE}"
                       type="application/octet-stream"
                       sparkle:edSignature="${SIGNATURE}" />
        </item>
EOF

# Create or update appcast
if [[ ! -f "${APPCAST_FILE}" ]]; then
    echo -e "${GREEN}📄 Creating appcast file...${NC}"
    cat > "${APPCAST_FILE}" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Caker Updates</title>
        <description>Automatic updates for Caker</description>
        <language>en</language>
        <link>https://github.com/Fred78290/caker</link>
$(cat "${TEMP_ITEM}")
    </channel>
</rss>
EOF
else
    echo -e "${GREEN}🔄 Updating appcast file...${NC}"
    # Insert new item after <link> line
    sed -i '' '/^[[:space:]]*<link>/r '"${TEMP_ITEM}" "${APPCAST_FILE}"
fi

rm "${TEMP_ITEM}"

# Summary
echo -e "${GREEN}✅ Release ${VERSION} signed and appcast updated${NC}"
echo
echo "📁 Generated files:"
echo "• Signed release: ${RELEASE_DEST}"
echo "• Appcast XML: ${APPCAST_FILE}"
echo "• Release notes: ${RELEASE_NOTES_FILE}"
echo
echo "📤 Next steps:"
echo "1. Publish release file on GitHub Releases"
echo "2. Publish appcast XML on your web server"
echo "3. Update SUFeedURL in Info.plist if necessary"
echo
echo "🔗 GitHub download URL:"
echo "https://github.com/Fred78290/caker/releases/download/v${VERSION}/${RELEASE_FILENAME}"