#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-}

source "${SCRIPT_DIR}/common.sh"

if [[ ! -d "${WIKI_DIR}" ]]; then
  echo "Error: wiki directory not found: ${WIKI_DIR}" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo "Usage: $0 <owner/repo>" >&2
  echo "Example: $0 Fred78290/caker" >&2
  exit 1
fi

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
USE_SSH="${USE_SSH:-0}"

WIKI_REMOTE_DISPLAY="https://github.com/${GITHUB_REPOSITORY}.wiki.git"

if [[ "${USE_SSH}" == "1" ]]; then
  WIKI_REMOTE="git@github.com:${GITHUB_REPOSITORY}.wiki.git"
elif [[ -n "${TOKEN}" ]]; then
  WIKI_REMOTE="https://x-access-token:${TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
else
  WIKI_REMOTE="${WIKI_REMOTE_DISPLAY}"
fi

if ! git ls-remote "${WIKI_REMOTE}" >/dev/null 2>&1; then
  echo "Unable to access remote wiki: ${WIKI_REMOTE_DISPLAY}" >&2
  echo "For a private repository, check GitHub authentication (GH_TOKEN/GITHUB_TOKEN or USE_SSH=1)." >&2
  echo "If repository access is OK but not the wiki, enable 'Wiki' in GitHub > Settings > Features." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Cloning remote wiki: ${WIKI_REMOTE_DISPLAY}"
git clone "${WIKI_REMOTE}" "${TMP_DIR}/wiki-repo"

cd "${TMP_DIR}/wiki-repo"
git config user.name "${GITHUB_REPOSITORY%%/*}"
WIKI_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo master)"

find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -R "${WIKI_DIR}/." .

# GitHub Wiki requires _Sidebar.md (capital S) for the sidebar to be recognised
if [[ -f "_sidebar.md" && ! -f "_Sidebar.md" ]]; then
  mv "_sidebar.md" "_Sidebar.md"
fi

git add .

if git diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi

COMMIT_MSG="${COMMIT_MSG:-Update wiki from repository}"
git commit -m "${COMMIT_MSG}"
git push origin "${WIKI_BRANCH}"

echo "Wiki successfully published to ${GITHUB_REPOSITORY}."
