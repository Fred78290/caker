#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIKI_DIR="${ROOT_DIR}/wiki"
DOCS_DIR="${ROOT_DIR}/docs"

echo "🔄 Synchronizing documentation from wiki to GitHub Pages..."

if [[ ! -d "${WIKI_DIR}" ]]; then
  echo "❌ Error: wiki directory not found: ${WIKI_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "❌ Error: docs directory not found: ${DOCS_DIR}" >&2
  exit 1
fi

# Function to convert wiki markdown to docs markdown
convert_wiki_to_docs() {
  local wiki_file="$1"
  local docs_file="$2"
  local title="$3"
  local nav_order="${4:-}"
  
  echo "  📄 Converting ${wiki_file} → ${docs_file}"
  
  # Create frontmatter
  {
    echo "---"
    echo "layout: page"
    echo "title: ${title}"
    if [[ -n "${nav_order}" ]]; then
      echo "nav_order: ${nav_order}"
    fi
    echo "---"
    echo ""
  } > "${docs_file}"
  
  # Convert wiki content to docs format
  sed \
    -e 's/\[Getting Started\](Getting-Started)/[Getting Started](getting-started)/g' \
    -e 's/\[Architecture\](Architecture)/[Architecture](architecture)/g' \
    -e 's/\[Development\](Development)/[Development](development)/g' \
    -e 's/\[Troubleshooting\](Troubleshooting)/[Troubleshooting](troubleshooting)/g' \
    -e 's/\[FAQ\](FAQ)/[FAQ](faq)/g' \
    -e 's/\[Release Notes\](Release-Notes)/[Release Notes](release-notes)/g' \
    -e 's/\[Command Summary\](Command-Summary)/[Command Summary](command-summary)/g' \
    -e 's/\[Cheat Sheet\](Cheat-Sheet)/[Cheat Sheet](cheat-sheet)/g' \
    -e 's|Resources/CakedAppIcon\.png|{{ "/assets/images/CakedAppIcon.png" \| relative_url }}|g' \
    "${wiki_file}" >> "${docs_file}"
}

# Convert individual pages
echo "📝 Converting wiki pages to docs format..."

# Getting Started (nav_order: 2)
if [[ -f "${WIKI_DIR}/Getting-Started.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Getting-Started.md" "${DOCS_DIR}/getting-started.md" "Getting Started" "2"
fi

# Architecture (nav_order: 3)
if [[ -f "${WIKI_DIR}/Architecture.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Architecture.md" "${DOCS_DIR}/architecture.md" "Architecture" "3"
fi

# Development (nav_order: 4)
if [[ -f "${WIKI_DIR}/Development.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Development.md" "${DOCS_DIR}/development.md" "Development" "4"
fi

# Command Summary (nav_order: 5)
if [[ -f "${WIKI_DIR}/Command-Summary.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Command-Summary.md" "${DOCS_DIR}/command-summary.md" "Command Summary" "5"
fi

# Troubleshooting (nav_order: 6)
if [[ -f "${WIKI_DIR}/Troubleshooting.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Troubleshooting.md" "${DOCS_DIR}/troubleshooting.md" "Troubleshooting" "6"
fi

# FAQ (nav_order: 7)
if [[ -f "${WIKI_DIR}/FAQ.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/FAQ.md" "${DOCS_DIR}/faq.md" "FAQ" "7"
fi

# Release Notes (nav_order: 8)
if [[ -f "${WIKI_DIR}/Release-Notes.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Release-Notes.md" "${DOCS_DIR}/release-notes.md" "Release Notes" "8"
fi

# Cheat Sheet (nav_order: 9)
if [[ -f "${WIKI_DIR}/Cheat-Sheet.md" ]]; then
  convert_wiki_to_docs "${WIKI_DIR}/Cheat-Sheet.md" "${DOCS_DIR}/cheat-sheet.md" "Cheat Sheet" "9"
fi

# Update main index page from wiki Home
if [[ -f "${WIKI_DIR}/Home.md" ]]; then
  echo "  📄 Updating home page from wiki Home.md"
  
  # Create updated index.md
  {
    echo "---"
    echo "layout: home"
    echo "title: Home"
    echo "nav_order: 1"
    echo "---"
    echo ""
    echo "# Caker"
    echo ""
    echo "![Caker App Icon]({{ '/assets/images/CakedAppIcon.png' | relative_url }}){: width=\"192\" }"
    echo ""
    echo "**Caker** is a Swift-native virtualization platform for macOS that streamlines VM lifecycle management from development to operations. It combines a powerful daemon (\`caked\`) with a practical CLI (\`cakectl\`) so teams can build, run, inspect, and automate virtual machines consistently."
    echo ""
    echo "[![Build](https://github.com/Fred78290/caker/actions/workflows/release.yaml/badge.svg?branch=main)](https://github.com/Fred78290/caker/actions/workflows/release.yaml)"
    echo "[![Publish Wiki](https://github.com/Fred78290/caker/actions/workflows/publish-wiki.yaml/badge.svg?branch=main)](https://github.com/Fred78290/caker/actions/workflows/publish-wiki.yaml)"
    echo "[![Documentation](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://caker.aldunelabs.com)"
    echo "[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/Fred78290/caker/blob/main/LICENSE)"
    echo ""
    
    # Add content from wiki Home, skipping the title and initial content
    tail -n +10 "${WIKI_DIR}/Home.md" | sed \
      -e 's/\[Getting Started\](Getting-Started)/[Getting Started](getting-started)/g' \
      -e 's/\[Architecture\](Architecture)/[Architecture](architecture)/g' \
      -e 's/\[Development\](Development)/[Development](development)/g' \
      -e 's/\[Troubleshooting\](Troubleshooting)/[Troubleshooting](troubleshooting)/g' \
      -e 's/\[FAQ\](FAQ)/[FAQ](faq)/g' \
      -e 's/\[Release Notes\](Release-Notes)/[Release Notes](release-notes)/g' \
      -e 's/\[Command Summary\](Command-Summary)/[Command Summary](command-summary)/g' \
      -e 's/\[Cheat Sheet\](Cheat-Sheet)/[Cheat Sheet](cheat-sheet)/g'
      
  } > "${DOCS_DIR}/index.md"
fi

echo "✅ Wiki to docs synchronization completed!"
echo ""
echo "📋 Updated files:"
find "${DOCS_DIR}" -name "*.md" -type f | sort | while read -r file; do
  echo "  • ${file#${ROOT_DIR}/}"
done

echo ""
echo "💡 Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Commit the updates: git add docs/ && git commit -m 'docs: sync from wiki'"
echo "  3. Push to update GitHub Pages: git push"