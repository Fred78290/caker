#!/bin/bash

# Automated GitHub publication script with Sparkle integration
# Usage: ./Scripts/sparkle-github-release.sh <version> <release-file> [description]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PATH="$HOMEBREW_PREFIX/Caskroom/sparkle/2.9.0/bin:$PATH" # Ensure scripts are in PATH for subcommands

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parameter validation
if [[ $# -lt 2 ]]; then
    echo -e "${RED}❌ Usage: $0 <version> <release-file> [description]${NC}"
    echo "Example: $0 1.2.3 /path/to/Caker-1.2.3.dmg 'Release with new features'"
    exit 1
fi

VERSION="$1"
RELEASE_FILE="$2"
RELEASE_DESCRIPTION="${3:-New version of Caker $VERSION}"

echo -e "${BLUE}🚀 GitHub publication with Sparkle${NC}"
echo "Version: $VERSION"
echo "File: $RELEASE_FILE"
echo "Description: $RELEASE_DESCRIPTION"
echo

# Prerequisites validation
if [[ ! -f "$RELEASE_FILE" ]]; then
    echo -e "${RED}❌ Release file not found: $RELEASE_FILE${NC}"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) required but not found${NC}"
    echo "Install GitHub CLI: brew install gh"
    echo "Or download from: https://cli.github.com/"
    exit 1
fi

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}🔐 GitHub authentication required${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Sign release with Sparkle first
echo -e "${BLUE}🔐 Sparkle signing...${NC}"
if ! "$SCRIPT_DIR/sparkle-sign-release.sh" "$VERSION" "$RELEASE_FILE"; then
    echo -e "${RED}❌ Sparkle signing failed${NC}"
    exit 1
fi

# Prepare release information
RELEASE_TAG="v$VERSION"
RELEASE_TITLE="Caker $VERSION"
RELEASE_NOTES_FILE="$PROJECT_ROOT/appcast/release-notes-$VERSION.html"

# Convert HTML notes to Markdown for GitHub
GITHUB_NOTES_FILE=$(mktemp)
if [[ -f "$RELEASE_NOTES_FILE" ]]; then
    echo "## $RELEASE_DESCRIPTION" > "$GITHUB_NOTES_FILE"
    echo "" >> "$GITHUB_NOTES_FILE"
    
    # Basic HTML -> Markdown conversion
    if command -v pandoc &> /dev/null; then
        pandoc -f html -t markdown "$RELEASE_NOTES_FILE" >> "$GITHUB_NOTES_FILE"
    else
        # Simple manual conversion
        sed -E 's|<h([0-9])>|##\1 |g; s|</h[0-9]>||g; s|<li>|• |g; s|</li>||g; s|<[^>]*>||g' "$RELEASE_NOTES_FILE" >> "$GITHUB_NOTES_FILE"
    fi
    
    # Add technical information
    echo "" >> "$GITHUB_NOTES_FILE"
    echo "### Technical Information" >> "$GITHUB_NOTES_FILE"
    echo "• Version: \`$VERSION\`" >> "$GITHUB_NOTES_FILE"
    echo "• Compatibility: macOS 15+" >> "$GITHUB_NOTES_FILE"
    echo "• Updates: Sparkle automatic" >> "$GITHUB_NOTES_FILE"
    echo "• Signature: Ed25519" >> "$GITHUB_NOTES_FILE"
else
    echo "$RELEASE_DESCRIPTION" > "$GITHUB_NOTES_FILE"
    echo "" >> "$GITHUB_NOTES_FILE"
    echo "### What's new" >> "$GITHUB_NOTES_FILE"
    echo "• Performance improvements" >> "$GITHUB_NOTES_FILE"
    echo "• Bug fixes" >> "$GITHUB_NOTES_FILE"
fi

# Check if tag already exists
if git rev-parse "$RELEASE_TAG" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Tag $RELEASE_TAG already exists${NC}"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -d "$RELEASE_TAG" || true
        git push origin :refs/tags/"$RELEASE_TAG" || true
    else
        echo -e "${RED}❌ Publication cancelled${NC}"
        exit 1
    fi
fi

# Create Git tag
echo -e "${BLUE}🏷️  Creating Git tag...${NC}"
git tag -a "$RELEASE_TAG" -m "$RELEASE_TITLE"
git push origin "$RELEASE_TAG"

# Create GitHub release
echo -e "${BLUE}📤 Publishing on GitHub...${NC}"
UPLOAD_URL=$(gh release create "$RELEASE_TAG" \
    --title "$RELEASE_TITLE" \
    --notes-file "$GITHUB_NOTES_FILE" \
    --draft)

if [[ -z "$UPLOAD_URL" ]]; then
    echo -e "${RED}❌ Release creation failed${NC}"
    exit 1
fi

# Upload release file
echo -e "${BLUE}📁 Uploading file...${NC}"
gh release upload "$RELEASE_TAG" "$RELEASE_FILE"

# Publish release (remove draft status)
echo -e "${BLUE}🎉 Final publication...${NC}"
gh release edit "$RELEASE_TAG" --draft=false

# Clean temporary files
rm -f "$GITHUB_NOTES_FILE"

# Check download URL
DOWNLOAD_URL="https://github.com/Fred78290/caker/releases/download/$RELEASE_TAG/$(basename "$RELEASE_FILE")"

echo -e "${GREEN}✅ Release published successfully${NC}"
echo
echo -e "${BLUE}📋 Publication details:${NC}"
echo "• Tag: $RELEASE_TAG"
echo "• URL: https://github.com/Fred78290/caker/releases/tag/$RELEASE_TAG"
echo "• Download: $DOWNLOAD_URL"
echo "• Appcast: $PROJECT_ROOT/appcast/appcast.xml"
echo
echo -e "${YELLOW}📤 Next steps:${NC}"
echo "1. Check release on GitHub"
echo "2. Test download and installation"
echo "3. Deploy appcast XML on your server"
echo "4. Test automatic updates"

# Optional: Publish appcast via GitHub Pages
APPCAST_FILE="$PROJECT_ROOT/appcast/appcast.xml"
if [[ -f "$APPCAST_FILE" ]]; then
    echo
    echo -e "${BLUE}📡 Options to publish appcast:${NC}"
    echo "1. GitHub Pages: Copy appcast/ to docs/ and enable Pages"
    echo "2. Personal server: Manual upload of appcast.xml"
    echo "3. CDN: Upload to your preferred CDN"
    echo
    echo "Example URL for GitHub Pages:"
    echo "https://fred78290.github.io/caker/appcast.xml"
fi