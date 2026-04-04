#!/bin/bash
set -euo pipefail

# Sparkle Custom Appcast XML Generator
# Generates a complete XML appcast for Sparkle updates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATH="${PROJECT_ROOT}/.bin:${PATH}" # Ensure scripts are in PATH for subcommands

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  REMOTE_URL="$(git -C "${PROJECT_ROOT}" config --get remote.origin.url || true)"

  if [[ -n "${REMOTE_URL}" ]]; then
    if [[ "${REMOTE_URL}" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      GITHUB_REPOSITORY="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
  fi
fi

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Fred78290/caker}"
APPCAST_DIR="${PROJECT_ROOT}/docs/appcast"
APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
MAX_RELEASES=10  # Number of recent releases to include

print_header() {
    echo -e "${BLUE}🚀 Sparkle Custom Appcast Generator${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -v, --version VER    Generate appcast for specific version"
    echo "  -o, --output PATH    Output directory (default: docs/appcast)"
    echo "  -r, --releases NUM   Number of releases to include (default: ${MAX_RELEASES})"
    echo "  --base-url URL       Base URL for downloads (default: GitHub releases)"
    echo
    echo "Examples:"
    echo "  $0                           # Generate full appcast"
    echo "  $0 -v 1.2.3                # Add specific version"
    echo "  $0 -r 5                    # Include only 5 most recent releases"
    echo "  $0 --base-url https://cdn.example.com/releases"
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v gh &> /dev/null; then
        missing_deps+=("GitHub CLI (gh)")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v xmllint &> /dev/null && ! command -v tidy &> /dev/null; then
        missing_deps+=("xmllint or tidy")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "   • ${dep}"
        done
        echo
        echo "Install with: brew install gh jq libxml2"
        exit 1
    fi
}

get_releases_data() {
    local limit=${1:-${MAX_RELEASES}}
    
    echo -e "${YELLOW}📡 Fetching releases from GitHub...${NC}"
    
    if ! gh api "/repos/${GITHUB_REPOSITORY}/releases" \
        --paginate \
        --jq "sort_by(.created_at) | reverse | .[:${limit}] | .[] | select(.draft == false)" \
        > "/tmp/caker_releases.json"; then
        echo -e "${RED}❌ Failed to fetch releases${NC}"
        exit 1
    fi
    
    local count=$(jq -s 'length' "/tmp/caker_releases.json")
    echo -e "${GREEN}✅ Found ${count} releases${NC}"
}

get_dmg_info() {
    local release_tag="$1"
    local assets_json="$2"
    local dmg_data=$(echo "${assets_json}" | jq -r '.[] | select(.name | test("\\.dmg$")) | {name: .name, download_url: .browser_download_url, size: .size}')

    if [ "${dmg_data}" = "null" ] || [ -z "${dmg_data}" ]; then
        echo "null"
        return
    fi
    
    echo "${dmg_data}"
}

get_sparkle_signature() {
    local release_tag="$1"
    local dmg_name="$2"
    
    # Look for signature file or generate it
    local sig_file="${PROJECT_ROOT}/.sparkle/signatures/${release_tag}.sig"
    
    if [ -f "${sig_file}" ]; then
        cat "${sig_file}"
    else
        # Try to generate signature if we have the DMG and keys
        local dmg_path="/tmp/${dmg_name}"
        if [ -f "${PROJECT_ROOT}/.sparkle/sparkle_private_key.pem" ] && [ -f "${dmg_path}" ]; then
            if command -v generate_appcast &> /dev/null; then
                generate_appcast \
                    --ed-key-file "${PROJECT_ROOT}/.sparkle/sparkle_private_key.pem" \
                    --download-url-prefix "" \
                    --output-file "/tmp/temp_appcast.xml" "${dmg_path}" 2>/dev/null | grep 'sparkle:edSignature' | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/' || echo ""
            fi
        fi
    fi
}

format_date() {
    local date_str="$1"
    
    # Convert ISO date to RFC 822 format
    if command -v gdate &> /dev/null; then
        gdate -d "${date_str}" '+%a, %d %b %Y %H:%M:%S %z'
    else
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "${date_str}" '+%a, %d %b %Y %H:%M:%S %z' 2>/dev/null || echo "${date_str}"
    fi
}

generate_xml_header() {
    cat << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Caker Updates</title>
        <link>https://github.com/Fred78290/caker</link>
        <description>Automatic updates for Caker - Virtual Machine Management Tool</description>
        <language>en</language>
        <lastBuildDate>$(date '+%a, %d %b %Y %H:%M:%S %z')</lastBuildDate>
        <docs>https://caker.aldunelabs.com/</docs>
        <generator>Sparkle Custom Appcast Generator</generator>
EOF
}

generate_release_item() {
    local release_data="$1"
    
    local tag_name=$(echo "${release_data}" | jq -r '.tag_name')
    local name=$(echo "${release_data}" | jq -r '.name // .tag_name')
    local body=$(echo "${release_data}" | jq -r '.body // ""')
    local published_at=$(echo "${release_data}" | jq -r '.published_at')
    local prerelease=$(echo "${release_data}" | jq -r '.prerelease')
    local assets=$(echo "${release_data}" | jq -r '.assets')
    
    # Get version number (remove 'v' prefix if present)
    local version="${tag_name#v}"
    
    # Get DMG information
    local dmg_data=$(get_dmg_info "${tag_name}" "${assets}")
    
    if [ "${dmg_data}" = "null" ]; then
        echo "⚠️  No DMG found for ${tag_name}, skipping..." >&2
        return
    fi
    
    local dmg_name=$(echo "${dmg_data}" | jq -r '.name')
    local dmg_url=$(echo "${dmg_data}" | jq -r '.download_url')
    local dmg_size=$(echo "${dmg_data}" | jq -r '.size')
    
    # Get Sparkle signature
    local signature=$(get_sparkle_signature "${tag_name}" "${dmg_name}")
    
    # Format date
    local pub_date=$(format_date "${published_at}")
    
    # Clean up release notes (escape HTML, limit length)
    local description=$(echo "${body}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
    
    cat << EOF
        <item>
            <title>${name}</title>
            <link>https://github.com/${GITHUB_REPOSITORY}/releases/tag/${tag_name}</link>
            <description><![CDATA[${description}]]></description>
            <pubDate>${pub_date}</pubDate>
            <guid isPermaLink="false">${tag_name}</guid>
            <sparkle:version>${version}</sparkle:version>
            <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure url="${dmg_url}"
                       length="${dmg_size}"
                       type="application/x-apple-diskimage"
EOF

    if [ -n "${signature}" ]; then
        echo "                       sparkle:edSignature=\"${signature}\""
    fi
    
    cat << EOF
                       sparkle:os="macos" />
EOF

    if [ "${prerelease}" = "true" ]; then
        echo "            <sparkle:tags><sparkle:prerelease/></sparkle:tags>"
    fi
    
    echo "        </item>"
}

generate_xml_footer() {
    cat << 'EOF'
    </channel>
</rss>
EOF
}

cleanup_xml() {
    local xml_file="$1"
    
    # Try to format XML nicely
    if command -v xmllint &> /dev/null; then
        xmllint --format "${xml_file}" > "${xml_file}.tmp" && mv "${xml_file}.tmp" "${xml_file}"
    elif command -v tidy &> /dev/null; then
        tidy -xml -i -q "${xml_file}" > "${xml_file}.tmp" 2>/dev/null && mv "${xml_file}.tmp" "${xml_file}"
    fi
}

generate_appcast() {
    echo -e "${YELLOW}🏗️  Generating appcast XML...${NC}"
    
    # Create output directory
    mkdir -p "${APPCAST_DIR}"
    
    # Start XML generation
    generate_xml_header > "${APPCAST_FILE}"
    
    # Process each release
    local count=0
    while IFS= read -r release_data; do
        if [ -n "${release_data}" ]; then
            generate_release_item "${release_data}" >> "${APPCAST_FILE}"
            ((count++))
        fi
    done < "/tmp/caker_releases.json"
    
    # Close XML
    generate_xml_footer >> "${APPCAST_FILE}"
    
    # Clean up XML formatting
    cleanup_xml "${APPCAST_FILE}"
    
    echo -e "${GREEN}✅ Generated appcast with ${count} releases${NC}"
    echo -e "${GREEN}📄 Appcast saved to: ${APPCAST_FILE}${NC}"
}

validate_appcast() {
    echo -e "${YELLOW}🔍 Validating appcast XML...${NC}"
    
    if command -v xmllint &> /dev/null; then
        if xmllint --noout "${APPCAST_FILE}" 2>/dev/null; then
            echo -e "${GREEN}✅ XML is valid${NC}"
        else
            echo -e "${RED}❌ XML validation failed${NC}"
            return 1
        fi
    fi
    
    # Check if file has content
    local item_count=$(grep -c '<item>' "${APPCAST_FILE}" || true)
    if [ "${item_count}" -gt 0 ]; then
        echo -e "${GREEN}✅ Found ${item_count} release items${NC}"
    else
        echo -e "${RED}❌ No release items found${NC}"
        return 1
    fi
}

display_summary() {
    echo
    echo -e "${BLUE}📊 Appcast Summary${NC}"
    echo -e "${BLUE}==================${NC}"
    echo -e "📁 File: ${GREEN}${APPCAST_FILE}${NC}"
    echo -e "📏 Size: ${GREEN}$(wc -c < "${APPCAST_FILE}" | xargs) bytes${NC}"
    echo -e "🔗 URL: ${GREEN}https://caker.aldunelabs.com/appcast/appcast.xml${NC}"
    echo
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo "1. Update Info.plist to use custom appcast:"
    echo "   SUFeedURL = https://caker.aldunelabs.com/appcast/appcast.xml"
    echo "2. Deploy to GitHub Pages or your preferred hosting"
    echo "3. Test with a debug build"
}

main() {
    local specific_version=""
    local output_dir=""
    local releases_count="${MAX_RELEASES}"
    local base_url=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--version)
                specific_version="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                APPCAST_DIR="${output_dir}"
                APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
                shift 2
                ;;
            -r|--releases)
                releases_count="$2"
                MAX_RELEASES="${releases_count}"
                shift 2
                ;;
            --base-url)
                base_url="$2"
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
    get_releases_data "${releases_count}"
    generate_appcast
    validate_appcast
    display_summary
    
    # Cleanup
    rm -f "/tmp/caker_releases.json"
    
    echo -e "${GREEN}🎉 Appcast generation completed successfully!${NC}"
}

# Run main function
main "$@"