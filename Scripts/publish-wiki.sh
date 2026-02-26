#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIKI_DIR="${ROOT_DIR}/wiki"

if [[ ! -d "${WIKI_DIR}" ]]; then
  echo "Erreur: dossier wiki introuvable: ${WIKI_DIR}" >&2
  exit 1
fi

OWNER="${1:-}"
REPO="${2:-}"

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  REMOTE_URL="$(git -C "${ROOT_DIR}" config --get remote.origin.url || true)"
  if [[ -n "${REMOTE_URL}" ]]; then
    if [[ "${REMOTE_URL}" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      OWNER="${OWNER:-${BASH_REMATCH[1]}}"
      REPO="${REPO:-${BASH_REMATCH[2]}}"
    fi
  fi
fi

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  echo "Usage: $0 <owner> <repo>" >&2
  echo "Exemple: $0 Fred78290 caker" >&2
  exit 1
fi

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
USE_SSH="${USE_SSH:-0}"

WIKI_REMOTE_DISPLAY="https://github.com/${OWNER}/${REPO}.wiki.git"

if [[ "${USE_SSH}" == "1" ]]; then
  WIKI_REMOTE="git@github.com:${OWNER}/${REPO}.wiki.git"
elif [[ -n "${TOKEN}" ]]; then
  WIKI_REMOTE="https://x-access-token:${TOKEN}@github.com/${OWNER}/${REPO}.wiki.git"
else
  WIKI_REMOTE="${WIKI_REMOTE_DISPLAY}"
fi

if ! git ls-remote "${WIKI_REMOTE}" >/dev/null 2>&1; then
  echo "Impossible d'accéder au wiki distant: ${WIKI_REMOTE_DISPLAY}" >&2
  echo "Pour un dépôt privé, vérifiez l'authentification GitHub (GH_TOKEN/GITHUB_TOKEN ou USE_SSH=1)." >&2
  echo "Si l'accès au repo est OK mais pas au wiki, activez 'Wiki' dans GitHub > Settings > Features." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Clonage du wiki distant: ${WIKI_REMOTE_DISPLAY}"
git clone "${WIKI_REMOTE}" "${TMP_DIR}/wiki-repo"

cd "${TMP_DIR}/wiki-repo"

WIKI_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo master)"

find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -R "${WIKI_DIR}/." .

git add .

if git diff --cached --quiet; then
  echo "Aucun changement à publier."
  exit 0
fi

COMMIT_MSG="${COMMIT_MSG:-Update wiki from repository}"
git commit -m "${COMMIT_MSG}"
git push origin "${WIKI_BRANCH}"

echo "Wiki publiée avec succès sur ${OWNER}/${REPO}."
