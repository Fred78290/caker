#!/bin/bash

# Sparkle release signing and publishing script
# Usage: ./Scripts/sparkle-sign-release.sh <version> <release-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

RELEASE_PATHS="${RELEASE_PATHS:-Sources wiki}"
SECTION_TITLE="## ${DATE_VALUE} (Git log summary - ${BRANCH_NAME})"

# Parameter validation
if [[ $# -lt 2 ]]; then
    echo -e "${RED}❌ Usage: $0 <version> <release-file>${NC}"
    echo "Example: $0 1.2.3 /path/to/Caker.dmg"
    exit 1
fi

VERSION="$1"
RELEASE_FILE="$2"

# Check if version contains snapshot
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
mkdir -p "${APPCAST_DIR}"

# Copy release file
RELEASE_FILENAME="$(basename "${RELEASE_FILE}")"

# Get file size
FILE_SIZE=$(stat -f%z "${RELEASE_FILE}")

# Sign file
echo -e "${GREEN}🔐 Signing file with Sparkle...${NC}"
SIGNATURE=$(sign_update "${RELEASE_FILE}" "${KEYS_DIR}/sparkle_private_key.pem")

echo -e "${GREEN}✅ Signature generated:${NC} ${SIGNATURE}"
echo

# Generate release information
RELEASE_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
RELEASE_NOTES_FILE="/tmp/release-notes.html"
LAST_RELEASE_TAG="$(gh release list --repo ${GITHUB_REPOSITORY} --exclude-pre-releases --json name,tagName,publishedAt,isDraft,isPrerelease | jq -r '.[0].tagName//""')"

if [ -n "${LAST_RELEASE_TAG}" ]; then
    SINCE_TAG="${LAST_RELEASE_TAG}...HEAD"
    COMMITS_RAW="$(git -C "${PROJECT_ROOT}" --no-pager log --no-merges --pretty=format:'<li>%s</li>' "${SINCE_TAG}" -- "${RELEASE_PATHS}")"

    if [[ -z "${COMMITS_RAW}" ]]; then
    COMMITS_RAW="$(git -C "${PROJECT_ROOT}" --no-pager log --no-merges --pretty=format:'<li>%s</li>' "${SINCE_TAG}")"
    fi
else
  COMMITS_RAW="<li>First release</li>"
fi

if [[ -z "${COMMITS_RAW}" ]]; then
  echo "${YELLOW}⚠️ No commits found to generate summary.${NC}"
  exit 0
fi

cat > "${RELEASE_NOTES_FILE}" << EOF
<h2>Caker ${VERSION}</h2>
<p>New version of Caker with improvements and bug fixes.</p>

<h3>${SECTION_TITLE}</h3>
<ul>
    ${COMMITS_RAW}
</ul>
EOF

echo -e "${GREEN}✅  Release notes created${NC}"

# Update or create appcast
APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
TEMP_ITEM=$(mktemp)

if [[ "${VERSION}" =~ SNAPSHOT ]]; then
    RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/${VERSION}/${RELEASE_FILENAME}"
else
    RELEASE_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/v${VERSION}/${RELEASE_FILENAME}"
fi

# Create new item
cat > "${TEMP_ITEM}" << EOF
        <item>
            <title>Caker ${VERSION}</title>
            <description><![CDATA[$(cat "${RELEASE_NOTES_FILE}")]]></description>
            <pubDate>${RELEASE_DATE}</pubDate>
            <enclosure url="${RELEASE_URL}"
                       sparkle:version="${VERSION}"
                       sparkle:shortVersionString="${VERSION}"
                       length="${FILE_SIZE}"
                       type="application/octet-stream"
                       sparkle:edSignature="${SIGNATURE}" />
        </item>
EOF

# Create or update appcast
if [[ ! -f "${APPCAST_FILE}" ]] || [[ -z $(grep -o '<item>' "${APPCAST_FILE}") ]]; then
    echo -e "${GREEN}📄 Creating appcast file...${NC}"
    cat > "${APPCAST_FILE}" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Caker Updates</title>
        <description>Automatic updates for Caker</description>
        <language>en</language>
        <link>https://github.com/${GITHUB_REPOSITORY}</link>
$(cat "${TEMP_ITEM}")
    </channel>
</rss>
EOF
else
    echo -e "${GREEN}🔄 Updating appcast file...${NC}"
    # Insert new item after <link> line
    sed -i '' '/^[[:space:]]*<item>/r '"${TEMP_ITEM}" "${APPCAST_FILE}"
fi

xmllint --format "${APPCAST_FILE}" > "${TEMP_ITEM}" && mv "${TEMP_ITEM}" "${APPCAST_FILE}"

# Summary
echo -e "${GREEN}✅ Release ${VERSION} signed and appcast updated${NC}"
echo
echo "📁 Generated files:"
echo "• Signed release: ${RELEASE_FILE}"
echo "• Appcast XML: ${APPCAST_FILE}"
echo "• Release notes: ${RELEASE_NOTES_FILE}"
echo
echo "📤 Next steps:"
echo "1. Publish release file on GitHub Releases"
echo "2. Publish appcast XML on your web server"
echo "3. Update SUFeedURL in Info.plist if necessary"
echo
echo "🔗 GitHub download URL:"
echo "${RELEASE_URL}"