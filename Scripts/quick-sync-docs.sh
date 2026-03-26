#!/usr/bin/env bash
set -euo pipefail

# Quick sync script for manual updates
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔄 Quick sync: docs ← wiki"

# Run the sync script
"${ROOT_DIR}/Scripts/sync-docs-from-wiki.sh"

# Check if there are changes
if git -C "${ROOT_DIR}" diff --quiet docs/; then
  echo "ℹ️ No changes detected in docs/"
  exit 0
fi

echo ""
echo "📋 Changes detected:"
git -C "${ROOT_DIR}" diff --name-only docs/ | sed 's/^/  • /'

echo ""
echo "💡 Quick commands:"
echo "  • Review changes: git diff docs/"
echo "  • Commit changes: git add docs/ && git commit -m 'docs: sync from wiki'"
echo "  • Push to GitHub:  git push"
echo "  • Do all at once:  git add docs/ && git commit -m 'docs: sync from wiki' && git push"