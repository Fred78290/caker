#!/bin/bash

# Sparkle integration script in build process
# Usage: ./Scripts/sparkle-build-integration.sh <build-type> <version>

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

BUILD_TYPE="${1:-release}"
VERSION="${2:-$(date +%Y.%m.%d)}"

echo -e "${BLUE}🏧️  Integrated build with Sparkle${NC}"
echo "Build type: $BUILD_TYPE"
echo "Version: $VERSION"
echo

# Function to detect version from git
detect_version() {
    if command -v git &> /dev/null && [[ -d "$PROJECT_ROOT/.git" ]]; then
        # Try to detect from git tags
        local git_version
        if git_version=$(git describe --tags --exact-match 2>/dev/null); then
            echo "$git_version" | sed 's/^v//'
        elif git_version=$(git describe --tags --abbrev=7 2>/dev/null); then
            echo "$git_version" | sed 's/^v//'
        else
            # Fallback with timestamp
            echo "$(date +%Y.%m.%d)-$(git rev-parse --short HEAD)"
        fi
    else
        echo "$(date +%Y.%m.%d)"
    fi
}

# Auto-detect version if not specified
if [[ "$VERSION" == "$(date +%Y.%m.%d)" ]]; then
    DETECTED_VERSION=$(detect_version)
    if [[ "$DETECTED_VERSION" != "$(date +%Y.%m.%d)" ]]; then
        VERSION="$DETECTED_VERSION"
        echo -e "${GREEN}📊 Detected version: $VERSION${NC}"
    fi
fi

# Selection of appropriate build script
case "$BUILD_TYPE" in
    "debug")
        BUILD_SCRIPT="$SCRIPT_DIR/build-signed-debug.sh"
        ;;
    "release")
        BUILD_SCRIPT="$SCRIPT_DIR/build-signed-release.sh"
        ;;
    "snapshot")
        BUILD_SCRIPT="$SCRIPT_DIR/build-signed-snapshot.sh"
        ;;
    *)
        echo -e "${RED}❌ Unsupported build type: $BUILD_TYPE${NC}"
        echo "Supported types: debug, release, snapshot"
        exit 1
        ;;
esac

if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo -e "${RED}❌ Build script not found: $BUILD_SCRIPT${NC}"
    exit 1
fi

# Check Sparkle configuration
KEYS_DIR="$PROJECT_ROOT/.sparkle"
if [[ ! -f "$KEYS_DIR/sparkle_private_key.pem" ]]; then
    echo -e "${YELLOW}⚠️  Sparkle keys not configured${NC}"
    echo "Automatic key configuration..."
    
    if ! "$SCRIPT_DIR/sparkle-generate-keys.sh"; then
        echo -e "${RED}❌ Sparkle configuration failed${NC}"
        exit 1
    fi
    echo
fi

# Update version in configuration files
echo -e "${BLUE}📝 Updating version...${NC}"

# Update in Info.plist
PLIST_FILE="$PROJECT_ROOT/Caker/Caker/Info.plist"
if [[ -f "$PLIST_FILE" ]] && command -v plutil &> /dev/null; then
    plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST_FILE"
    plutil -replace CFBundleVersion -string "$VERSION" "$PLIST_FILE"
    echo -e "${GREEN}✅ Version updated in Info.plist${NC}"
fi

# Execute main build
echo -e "${BLUE}🔨 Starting build...${NC}"
if ! "$BUILD_SCRIPT" "$PROJECT_ROOT"; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build completed successfully${NC}"
echo

# Find generated distribution file
DIST_DIR="$PROJECT_ROOT/build"
APP_NAME="Caker.app"
DMG_NAME="Caker-$VERSION.dmg"

# Search for .app or .dmg file generated
if [[ -d "$DIST_DIR/$APP_NAME" ]]; then
    BUILT_APP="$DIST_DIR/$APP_NAME"
elif [[ -f "$DIST_DIR/$DMG_NAME" ]]; then
    BUILT_DMG="$DIST_DIR/$DMG_NAME"
else
    # Search in other possible locations
    BUILT_APP=$(find "$PROJECT_ROOT" -name "Caker.app" -type d -newer "$BUILD_SCRIPT" | head -1)
    if [[ -z "$BUILT_APP" ]]; then
        echo -e "${YELLOW}⚠️  .app file not found automatically${NC}"
        echo "Manually specify path for Sparkle signing"
        exit 0
    fi
fi

# Create DMG if necessary (only for releases)
if [[ "$BUILD_TYPE" == "release" && ! -f "$DIST_DIR/$DMG_NAME" ]]; then
    echo -e "${BLUE}📦 Creating distribution DMG...${NC}"
    
    # Create build folder if it doesn't exist
    mkdir -p "$DIST_DIR"
    
    # Create simple DMG
    if command -v create-dmg &> /dev/null; then
        create-dmg \
            --volname "Caker $VERSION" \
            --window-pos 200 120 \
            --window-size 800 600 \
            --icon-size 100 \
            --app-drop-link 600 300 \
            "$DIST_DIR/$DMG_NAME" \
            "$BUILT_APP"
    else
        # Fallback with hdiutil
        TEMP_DIR=$(mktemp -d)
        cp -R "$BUILT_APP" "$TEMP_DIR/"
        hdiutil create -srcfolder "$TEMP_DIR" -volname "Caker $VERSION" "$DIST_DIR/$DMG_NAME"
        rm -rf "$TEMP_DIR"
    fi
    
    BUILT_DMG="$DIST_DIR/$DMG_NAME"
    echo -e "${GREEN}✅ DMG created: $BUILT_DMG${NC}"
fi

# Automatic Sparkle signing for releases
if [[ "$BUILD_TYPE" == "release" && -n "${BUILT_DMG:-}" && -f "$BUILT_DMG" ]]; then
    echo -e "${BLUE}🔐 Sparkle signing of release...${NC}"
    
    if "$SCRIPT_DIR/sparkle-sign-release.sh" "$VERSION" "$BUILT_DMG"; then
        echo -e "${GREEN}✅ Release signed and appcast updated${NC}"
        echo
        echo -e "${BLUE}📋 Release summary:${NC}"
        echo "• Version: $VERSION"
        echo "• File: $BUILT_DMG"
        echo "• Signature: Sparkle Ed25519"
        echo "• Appcast: $PROJECT_ROOT/appcast/appcast.xml"
        echo
        echo -e "${YELLOW}📤 Next steps:${NC}"
        echo "1. Test DMG installation"
        echo "2. Publish on GitHub Releases"
        echo "3. Deploy appcast XML"
    else
        echo -e "${RED}❌ Sparkle signing failed${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}ℹ️  Sparkle signing ignored for $BUILD_TYPE build${NC}"
    if [[ -n "${BUILT_APP:-}" ]]; then
        echo "Generated file: $BUILT_APP"
    fi
fi

echo -e "${GREEN}🎉 Sparkle integrated build completed successfully${NC}"