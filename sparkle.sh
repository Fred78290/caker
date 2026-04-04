#!/bin/bash

# Main Sparkle automation script for Caker
# Usage: ./sparkle.sh <command> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
PATH="${PROJECT_ROOT}/.bin:${PATH}" # Ensure scripts are in PATH for subcommands

# Load configuration
if [[ -f "${PROJECT_ROOT}/sparkle.conf" ]]; then
    source "${PROJECT_ROOT}/sparkle.conf"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Help function
show_help() {
    cat << EOF
${BLUE}🚀 Sparkle Automation for Caker${NC}

${YELLOW}Usage:${NC}
  ./sparkle.sh <command> [options]

${YELLOW}Available commands:${NC}

${GREEN}Initial configuration:${NC}
  setup                 Complete Sparkle configuration
  keys                  Generate signing keys
  config                Show current configuration
  status                Check configuration status

${GREEN}Build and development:${NC}
  build [type]          Build with Sparkle integration
                        Types: debug, release, snapshot (default: release)
  clean                 Clean build files
  test                  Test Sparkle configuration

${GREEN}Release and publication:${NC}
  sign <version> <file> Sign file with Sparkle
  release <version>     Build and publish complete release
  github <version> <file> [desc]  Publish on GitHub
  appcast [generate|deploy|status] Generate, deploy or check appcast XML

${GREEN}Utilities:${NC}
  verify <file>         Verify Sparkle signature
  info <file>           Show file information
  help                  Show this help

${YELLOW}Examples:${NC}
  ./sparkle.sh setup                           # Initial configuration
  ./sparkle.sh build release                   # Release build
  ./sparkle.sh release 1.2.3                  # Complete release v1.2.3
  ./sparkle.sh github 1.2.3 build/Caker.dmg   # GitHub publication

${YELLOW}Environment variables:${NC}
  SPARKLE_VERSION       Version to use (auto-detected if omitted)
  SPARKLE_SKIP_TESTS    Skip tests (true/false)
  SPARKLE_VERBOSE       Verbose mode (true/false)

EOF
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "${level}" in
        "info")  echo -e "${BLUE}ℹ️  ${message}${NC}" ;;
        "ok")    echo -e "${GREEN}✅ ${message}${NC}" ;;
        "warn")  echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        "error") echo -e "${RED}❌ ${message}${NC}" ;;
        "step")  echo -e "${PURPLE}🔹 ${message}${NC}" ;;
    esac
}

# Automatically detect version
detect_version() {
    if [[ -n "${SPARKLE_VERSION:-}" ]]; then
        echo "${SPARKLE_VERSION}"
    elif command -v git &> /dev/null && [[ -d "${PROJECT_ROOT}/.git" ]]; then
        if git describe --tags --exact-match 2>/dev/null; then
            git describe --tags --exact-match | sed 's/^v//'
        else
            echo "$(date +%Y.%m.%d)-dev"
        fi
    else
        echo "$(date +%Y.%m.%d)"
    fi
}

# Vérifier les prérequis
check_requirements() {
    local missing=()
    
    if ! command -v swift &> /dev/null; then
        missing+=("swift (Xcode Command Line Tools)")
    fi
    
    if ! command -v generate_keys &> /dev/null; then
        missing+=("sparkle (brew install sparkle)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log error "Missing prerequisites:"
        printf '%s\n' "${missing[@]}" | sed 's/^/  • /'
        return 1
    fi
}

# Initial configuration
cmd_setup() {
    log step "Initial Sparkle configuration"
    
    # Check prerequisites
    if ! check_requirements; then
        return 1
    fi
    
    # Generate keys
    "${PROJECT_ROOT}/Scripts/sparkle-generate-keys.sh"
    
    # Check configuration
    cmd_status
    
    log ok "Sparkle configuration completed"
    echo
    log info "Next steps:"
    echo "  1. Test: ./sparkle.sh build debug"
    echo "  2. Release: ./sparkle.sh release 1.0.0"
}

# Générer les clés
cmd_keys() {
    "${PROJECT_ROOT}/Scripts/sparkle-generate-keys.sh"
}

# Show configuration
cmd_config() {
    log step "Current Sparkle configuration"
    echo
    echo "📁 Project: ${PROJECT_ROOT}"
    echo "📱 App: ${APP_NAME:-Caker}"
    echo "📦 Bundle ID: ${BUNDLE_ID:-com.aldunelabs.caker}"
    echo "🔗 Repository: ${GITHUB_REPO:-Fred78290/caker}"
    echo "📡 Appcast: ${APPCAST_URL:-GitHub Releases}"
    echo "🔄 Interval: ${UPDATE_CHECK_INTERVAL:-86400}s"
    echo
    if [[ -f "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem" ]]; then
        echo "🔑 Public key:"
        cat "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem"
    fi
}

# Check status
cmd_status() {
    log step "Checking Sparkle status"
    echo
    
    local status=0
    
    # Check keys
    if [[ -f "${PROJECT_ROOT}/.sparkle/sparkle_private_key.pem" && -f "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem" ]]; then
        log ok "Signing keys present"
    else
        log error "Signing keys missing"
        status=1
    fi
    
    # Check Info.plist
    if [[ -f "${PROJECT_ROOT}/Caker/Caker/Info.plist" ]]; then
        if grep -q "REPLACEME_WITH_ACTUAL_PUBLIC_KEY" "${PROJECT_ROOT}/Caker/Caker/Info.plist" 2>/dev/null; then
            log warn "Info.plist not configured (placeholder public key)"
            status=1
        else
            log ok "Info.plist configured"
        fi
    else
        log error "Info.plist not found"
        status=1
    fi
    
    # Check Package.swift
    if grep -q "sparkle-project/Sparkle" "${PROJECT_ROOT}/Package.swift" 2>/dev/null; then
        log ok "Sparkle dependency present in Package.swift"
    else
        log error "Sparkle dependency missing in Package.swift"
        status=1
    fi
    
    # Check tools
    if check_requirements 2>/dev/null; then
        log ok "Prerequisites installed"
    else
        log warn "Some prerequisites are missing"
        status=1
    fi
    
    echo
    if [[ ${status} -eq 0 ]]; then
        log ok "Sparkle configuration complete and functional"
    else
        log warn "Incomplete configuration - run: ./sparkle.sh setup"
    fi
    
    return ${status}
}

# Build with integration
cmd_build() {
    local build_type="${1:-release}"
    local version="${2:-$(detect_version)}"
    
    log step "Sparkle build: ${build_type} (v${version})"
    "${PROJECT_ROOT}/Scripts/sparkle-build-integration.sh" "${build_type}" "${version}"
}

# Clean
cmd_clean() {
    log step "Cleaning build files"
    
    rm -rf "${PROJECT_ROOT}/build"
    rm -rf "${PROJECT_ROOT}/releases"
    rm -rf "${PROJECT_ROOT}/DerivedData"
    rm -rf "${PROJECT_ROOT}/.build"
    
    log ok "Cleanup completed"
}

# Sign a file
cmd_sign() {
    local version="$1"
    local file="$2"
    
    log step "Sparkle signing: ${file} (v${version})"
    "${PROJECT_ROOT}/Scripts/sparkle-sign-release.sh" "${version}" "${file}"
}

# Complete release
cmd_release() {
    local version="${1:-$(detect_version)}"
    
    log step "Complete release v${version}"
    
    # Build
    cmd_build release "${version}"
    
    # Find generated file
    local dmg_file="${PROJECT_ROOT}/build/Caker-${version}.dmg"
    if [[ ! -f "${dmg_file}" ]]; then
        dmg_file="${PROJECT_ROOT}/releases/Caker-${version}.dmg"
    fi
    
    if [[ -f "${dmg_file}" ]]; then
        log ok "Release v${version} generated: ${dmg_file}"
    else
        log error "Release file not found"
        return 1
    fi
}

# GitHub publication
cmd_github() {
    local version="$1"
    local file="$2"
    local description="${3:-Release v${version}}"
    
    log step "GitHub publication: v${version}"
    "${PROJECT_ROOT}/Scripts/sparkle-github-release.sh" "${version}" "${file}" "${description}"
}

# Appcast management
cmd_appcast() {
    local action="${1:-generate}"
    
    case "${action}" in
        "generate")
            log step "Generating custom XML appcast"
            "${PROJECT_ROOT}/Scripts/sparkle-generate-appcast-xml.sh"
            ;;
        "deploy")
            log step "Deploying appcast to GitHub Pages"
            "${PROJECT_ROOT}/Scripts/sparkle-deploy-appcast.sh"
            ;;
        "status")
            log step "Checking appcast status"
            
            # Check if appcast file exists
            if [[ -f "${PROJECT_ROOT}/docs/appcast/appcast.xml" ]]; then
                local item_count=$(grep -c '<item>' "${PROJECT_ROOT}/docs/appcast/appcast.xml" || echo "0")
                log ok "Appcast file exists with ${item_count} releases"
                echo "📄 File: docs/appcast/appcast.xml"
                echo "🌐 URL: https://caker.aldunelabs.com/appcast/appcast.xml"
            else
                log error "Appcast file not found"
                echo "Run: ./sparkle.sh appcast generate"
                return 1
            fi
            
            # Test if URL is accessible
            if command -v curl &> /dev/null; then
                local appcast_url="https://caker.aldunelabs.com/appcast/appcast.xml"
                if curl -sSf "${appcast_url}" > /dev/null 2>&1; then
                    log ok "Appcast is accessible online"
                else
                    log warn "Appcast URL not accessible (may need deployment)"
                fi
            fi
            ;;
        "help"|*)
            echo "Usage: ./sparkle.sh appcast [generate|deploy|status]"
            echo
            echo "Commands:"
            echo "  generate  Generate appcast.xml from GitHub releases"
            echo "  deploy    Deploy appcast to GitHub Pages"
            echo "  status    Check appcast status and accessibility"
            ;;
    esac
}

# Main command
case "${1:-help}" in
    "setup")    cmd_setup ;;
    "keys")     cmd_keys ;;
    "config")   cmd_config ;;
    "status")   cmd_status ;;
    "build")    cmd_build "${2:-release}" "${3:-}" ;;
    "clean")    cmd_clean ;;
    "sign")     cmd_sign "$2" "$3" ;;
    "release")  cmd_release "${2:-}" ;;
    "github")   cmd_github "$2" "$3" "${4:-}" ;;
    "appcast")  cmd_appcast "${2:-generate}" ;;
    "test")     cmd_status ;;
    "help"|*)   show_help ;;
esac