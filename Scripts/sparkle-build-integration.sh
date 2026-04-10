#!/bin/bash

# Sparkle integration script in build process
# Usage: ./Scripts/sparkle-build-integration.sh <build-type> <version>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common.sh"

BUILD_TYPE="${1:-release}"
VERSION="${2:-$(date +%Y.%m.%d)}"

echo -e "${BLUE}🏧️  Integrated build with Sparkle${NC}"
echo "Build type: ${BUILD_TYPE}"
echo "Version: ${VERSION}"
echo

if [[ "${VERSION}" =~ SNAPSHOT ]]; then
    APPCAST_FILE="${APPCAST_DIR}/appcast-prerelease.xml"
else
    APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
fi

# Function to detect version from git
detect_version() {
    if command -v git &> /dev/null && [[ -d "${PROJECT_ROOT}/.git" ]]; then
        # Try to detect from git tags
        local git_version
        if git_version=$(git describe --tags --exact-match 2>/dev/null); then
            echo "${git_version}" | sed 's/^v//'
        elif git_version=$(git describe --tags --abbrev=7 2>/dev/null); then
            echo "${git_version}" | sed 's/^v//'
        else
            # Fallback with timestamp
            echo "$(date +%Y.%m.%d)-$(git rev-parse --short HEAD)"
        fi
    else
        echo "$(date +%Y.%m.%d)"
    fi
}

# Auto-detect version if not specified
if [[ "${VERSION}" == "$(date +%Y.%m.%d)" ]]; then
    DETECTED_VERSION=$(detect_version)
    if [[ "${DETECTED_VERSION}" != "$(date +%Y.%m.%d)" ]]; then
        VERSION="${DETECTED_VERSION}"
        echo -e "${GREEN}📊 Detected version: ${VERSION}${NC}"
    fi
fi

DMG_NAME="Caker.dmg"

# Selection of appropriate build script
case "${BUILD_TYPE}" in
    "debug")
        BUILD_SCRIPT="${SCRIPT_DIR}/build-signed-debug.sh"
        ;;
    "release")
        BUILD_SCRIPT="${SCRIPT_DIR}/build-signed-release.sh"
        ;;
    *)
        echo -e "${RED}❌ Unsupported build type: ${BUILD_TYPE}${NC}"
        echo "Supported types: debug, release"
        exit 1
        ;;
esac

# Find generated distribution file
BUILT_APP="${DIST_DIR}/${APP_NAME}"
export PKGDIR="${BUILT_APP}"

if [[ ! -f "${BUILD_SCRIPT}" ]]; then
    echo -e "${RED}❌ Build script not found: ${BUILD_SCRIPT}${NC}"
    exit 1
fi

# Check Sparkle configuration
if [[ ! -f "${KEYS_DIR}/sparkle_private_key.pem" ]]; then
    echo -e "${YELLOW}⚠️  Sparkle keys not configured${NC}"
    echo "Automatic key configuration..."
    
    if ! "${SCRIPT_DIR}/sparkle-generate-keys.sh"; then
        echo -e "${RED}❌ Sparkle configuration failed${NC}"
        exit 1
    fi
    echo
fi

# Execute main build
echo -e "${BLUE}🔨 Starting build...${NC}"
if ! "${BUILD_SCRIPT}" "${PROJECT_ROOT}"; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build completed successfully${NC}"
echo

# Create DMG if necessary (only for releases)
if [[ "${BUILD_TYPE}" == "release" ]]; then
    echo -e "${BLUE}📦 Creating distribution DMG...${NC}"
    
    # Create build folder if it doesn't exist
    mkdir -p "${DIST_DIR}"
    
    # Create simple DMG
    create-dmg \
        --volname "Caker ${VERSION}" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "Caker.app" 200 190 \
        --hide-extension "Caker.app" \
        --app-drop-link 600 185 \
        --background "${PROJECT_ROOT}/.ci/dmg-resources/background.png" \
        "${DIST_DIR}/${DMG_NAME}" \
        "${BUILT_APP}"
    
    BUILT_DMG="${DIST_DIR}/${DMG_NAME}"
    echo -e "${GREEN}✅ DMG created: ${BUILT_DMG}${NC}"
fi

# Automatic Sparkle signing for releases
if [[ "${BUILD_TYPE}" == "release" && -n "${BUILT_DMG:-}" && -f "${BUILT_DMG}" ]]; then
    echo -e "${BLUE}🔐 Sparkle signing of release...${NC}"
    
    if "${SCRIPT_DIR}/sparkle-sign-release.sh" "${VERSION}" "${BUILT_DMG}"; then
        echo -e "${GREEN}✅ Release signed and appcast updated${NC}"
        echo
        echo -e "${BLUE}📋 Release summary:${NC}"
        echo "• Version: ${VERSION}"
        echo "• File: ${BUILT_DMG}"
        echo "• Signature: Sparkle Ed25519"
        echo "• Appcast: ${APPCAST_FILE}"
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
    echo -e "${BLUE}ℹ️  Sparkle signing ignored for ${BUILD_TYPE} build${NC}"
    if [[ -n "${BUILT_APP:-}" ]]; then
        echo "Generated file: ${BUILT_APP}"
    fi
fi

echo -e "${GREEN}🎉 Sparkle integrated build completed successfully${NC}"
