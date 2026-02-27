#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_NOTES_FILE="${ROOT_DIR}/wiki/Release-Notes.md"
BRANCH_NAME="${1:-$(git -C "${ROOT_DIR}" rev-parse --abbrev-ref HEAD)}"
DATE_VALUE="${2:-$(date +%F)}"
MAX_COMMITS="${MAX_COMMITS:-20}"
RELEASE_PATHS="${RELEASE_PATHS:-Sources wiki}"

if [[ ! -f "${RELEASE_NOTES_FILE}" ]]; then
  echo "Error: file not found: ${RELEASE_NOTES_FILE}" >&2
  exit 1
fi

SECTION_TITLE="## ${DATE_VALUE} (Git log summary - ${BRANCH_NAME})"

if grep -Fq "${SECTION_TITLE}" "${RELEASE_NOTES_FILE}"; then
  echo "Section already exists: ${SECTION_TITLE}"
  exit 0
fi

read -r -a PATH_FILTERS <<< "${RELEASE_PATHS}"

COMMITS_RAW="$(git -C "${ROOT_DIR}" --no-pager log --no-merges --pretty=format:'- %s' -n "${MAX_COMMITS}" -- "${PATH_FILTERS[@]}")"

COMMAND_USED="git log --no-merges --oneline -n ${MAX_COMMITS} -- ${RELEASE_PATHS}"

if [[ -z "${COMMITS_RAW}" ]]; then
  COMMITS_RAW="$(git -C "${ROOT_DIR}" --no-pager log --no-merges --pretty=format:'- %s' -n "${MAX_COMMITS}")"
  COMMAND_USED="git log --no-merges --oneline -n ${MAX_COMMITS}"
fi

if [[ -z "${COMMITS_RAW}" ]]; then
  echo "No commits found to generate summary."
  exit 0
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

{
  echo "${SECTION_TITLE}"
  echo
  echo "### Added"
  echo "- See commit highlights below."
  echo
  echo "### Updated"
  echo "${COMMITS_RAW}"
  echo
  echo "### Notes"
  echo "- Summary generated automatically from recent git commits on branch \`${BRANCH_NAME}\`."
  echo "- Command used: \`${COMMAND_USED}\`."
  echo
} > "${TMP_FILE}"

FIRST_LINE="$(head -n 1 "${RELEASE_NOTES_FILE}" || true)"

if [[ "${FIRST_LINE}" == "# Release Notes" ]]; then
  {
    echo "${FIRST_LINE}"
    echo
    cat "${TMP_FILE}"
    tail -n +2 "${RELEASE_NOTES_FILE}"
  } > "${TMP_FILE}.new"
else
  {
    cat "${TMP_FILE}"
    cat "${RELEASE_NOTES_FILE}"
  } > "${TMP_FILE}.new"
fi

mv "${TMP_FILE}.new" "${RELEASE_NOTES_FILE}"

echo "Release notes updated from git log: ${SECTION_TITLE}"
