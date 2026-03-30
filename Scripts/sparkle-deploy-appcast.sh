#!/bin/bash
set -euo pipefail

# Deploy Sparkle Appcast to GitHub Pages
# This script deploys the generated appcast to GitHub Pages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATH="${HOMEBREW_PREFIX}/Caskroom/sparkle/2.9.0/bin:${PATH}" # Ensure scripts are in PATH for subcommands

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}🌐 Sparkle Appcast Deployment${NC}"
    echo -e "${BLUE}===============================${NC}"
    echo
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -f, --force          Force deployment even if no changes"
    echo "  -d, --dry-run        Show what would be deployed without actually deploying"
    echo "  --branch BRANCH      Target branch for GitHub Pages (default: main)"
    echo
    echo "Examples:"
    echo "  $0                   # Deploy if changes detected"
    echo "  $0 --force          # Force deployment"
    echo "  $0 --dry-run        # Preview deployment"
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "   • ${dep}"
        done
        exit 1
    fi
}

check_git_status() {
    cd "${PROJECT_ROOT}"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        exit 1
    fi
    
    # Check if docs/appcast exists
    if [ ! -d "docs/appcast" ]; then
        echo -e "${RED}❌ Appcast directory not found: docs/appcast${NC}"
        exit 1
    fi
    
    # Check if appcast.xml exists
    if [ ! -f "docs/appcast/appcast.xml" ]; then
        echo -e "${RED}❌ Appcast file not found: docs/appcast/appcast.xml${NC}"
        echo "Run: ./Scripts/sparkle-generate-appcast-xml.sh"
        exit 1
    fi
}

check_changes() {
    cd "${PROJECT_ROOT}"
    
    # Check if there are changes in docs/appcast/
    if git diff --quiet docs/appcast/; then
        if git diff --cached --quiet docs/appcast/; then
            echo -e "${YELLOW}📄 No changes detected in docs/appcast/${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}📄 Changes detected in docs/appcast/${NC}"
    return 0
}

show_changes() {
    cd "${PROJECT_ROOT}"
    
    echo -e "${YELLOW}📊 Changes to be deployed:${NC}"
    echo
    
    git diff --name-status docs/appcast/ || true
    git diff --cached --name-status docs/appcast/ || true
    
    echo
    echo -e "${YELLOW}📄 Appcast content preview:${NC}"
    
    # Show first few lines of appcast
    head -20 docs/appcast/appcast.xml | sed 's/^/  /'
    
    local item_count=$(grep -c '<item>' docs/appcast/appcast.xml || echo "0")
    echo -e "${GREEN}  ... (${item_count} release items total)${NC}"
}

deploy_appcast() {
    cd "${PROJECT_ROOT}"
    
    echo -e "${YELLOW}🚀 Deploying appcast to GitHub Pages...${NC}"
    
    # Configure git user if not set (for CI environments)
    if [ -z "$(git config user.name || true)" ]; then
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
    fi
    
    # Add appcast files
    git add docs/appcast/
    
    # Create commit
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local item_count=$(grep -c '<item>' docs/appcast/appcast.xml || echo "0")
    
    git commit -m "🌐 Update Sparkle appcast - ${item_count} releases (${timestamp})" || {
        echo -e "${YELLOW}⚠️  No changes to commit${NC}"
        return 0
    }
    
    # Push to remote
    local branch="${1:-main}"
    echo -e "${YELLOW}📤 Pushing to branch: ${branch}${NC}"
    
    if git push origin "${branch}"; then
        echo -e "${GREEN}✅ Successfully deployed appcast${NC}"
        
        # Show deployment URL
        echo
        echo -e "${BLUE}🌐 Appcast URLs:${NC}"
        echo -e "   Production: ${GREEN}https://caker.aldunelabs.com/appcast/appcast.xml${NC}"
        echo -e "   GitHub: ${GREEN}https://github.com/Fred78290/caker/blob/${branch}/docs/appcast/appcast.xml${NC}"
    else
        echo -e "${RED}❌ Failed to push changes${NC}"
        exit 1
    fi
}

validate_deployment() {
    echo -e "${YELLOW}🔍 Validating deployment...${NC}"
    
    # Wait a moment for GitHub Pages to update
    sleep 2
    
    # Try to fetch the deployed appcast
    local appcast_url="https://caker.aldunelabs.com/appcast/appcast.xml"
    
    if command -v curl &> /dev/null; then
        echo -e "${YELLOW}📡 Testing appcast URL...${NC}"
        
        if curl -sSf "${appcast_url}" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Appcast is accessible at ${appcast_url}${NC}"
        else
            echo -e "${YELLOW}⚠️  Appcast may not be immediately available (GitHub Pages deployment in progress)${NC}"
            echo -e "${YELLOW}   URL: ${appcast_url}${NC}"
        fi
    fi
}

main() {
    local force=false
    local dry_run=false
    local branch="main"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                print_usage
                exit 1
                ;;
        esac
    done
    
    print_header
    check_dependencies
    check_git_status
    
    # Check for changes unless forced
    if [ "${force}" = false ] && ! check_changes; then
        echo -e "${GREEN}✅ No deployment needed${NC}"
        exit 0
    fi
    
    show_changes
    
    if [ "${dry_run}" = true ]; then
        echo -e "${YELLOW}🔍 Dry run complete - no changes deployed${NC}"
        exit 0
    fi
    
    echo
    read -p "Deploy appcast to GitHub Pages? [y/N] " -n 1 -r
    echo
    
    if [[ ${REPLY} =~ ^[Yy]$ ]]; then
        deploy_appcast "${branch}"
        validate_deployment
        echo -e "${GREEN}🎉 Appcast deployment completed!${NC}"
    else
        echo -e "${YELLOW}❌ Deployment cancelled${NC}"
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi