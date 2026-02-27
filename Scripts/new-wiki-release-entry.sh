#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_NOTES_FILE="${ROOT_DIR}/wiki/Release-Notes.md"
ENTRY_DATE="${1:-$(date +%F)}"

if [[ ! -f "${RELEASE_NOTES_FILE}" ]]; then
  echo "Error: file not found: ${RELEASE_NOTES_FILE}" >&2
  exit 1
fi

if grep -q "^## ${ENTRY_DATE}$" "${RELEASE_NOTES_FILE}"; then
  echo "Entry already exists for ${ENTRY_DATE}."
  exit 0
fi

ENTRY_CONTENT=$(cat <<EOF
## ${ENTRY_DATE}

### Added
- ...

### Updated
- ...

### Notes
- ...

EOF
)

TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

FIRST_LINE="$(head -n 1 "${RELEASE_NOTES_FILE}")"
if [[ "${FIRST_LINE}" == "# Release Notes" ]]; then
  {
    echo "${FIRST_LINE}"
    echo
    echo "${ENTRY_CONTENT}"
    tail -n +2 "${RELEASE_NOTES_FILE}"
  } > "${TMP_FILE}"
else
  {
    cat "${RELEASE_NOTES_FILE}"
    echo
    echo "${ENTRY_CONTENT}"
  } > "${TMP_FILE}"
fi

mv "${TMP_FILE}" "${RELEASE_NOTES_FILE}"

echo "New entry added ${ENTRY_DATE} in wiki/Release-Notes.md"
