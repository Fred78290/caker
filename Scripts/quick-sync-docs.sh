#!/usr/bin/env bash
set -euo pipefail

# Quick sync script for manual updates
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🔄 Quick sync: docs ← wiki"

# Run the sync script
"${PROJECT_ROOT}/Scripts/sync-docs-from-wiki.sh"

# Check if there are changes
if git -C "${PROJECT_ROOT}" diff --quiet docs/; then
  echo "ℹ️ No changes detected in docs/"
  exit 0
fi

echo ""
echo "📋 Changes detected:"
git -C "${PROJECT_ROOT}" diff --name-only docs/ | sed 's/^/  • /'

echo ""
echo "💡 Quick commands:"
echo "  • Review changes: git diff docs/"
echo "  • Commit changes: git add docs/ && git commit -m 'docs: sync from wiki'"
echo "  • Push to GitHub:  git push"
echo "  • Do all at once:  git add docs/ && git commit -m 'docs: sync from wiki' && git push"