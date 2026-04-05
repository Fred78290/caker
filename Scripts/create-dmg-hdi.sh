#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}"
BUILD_DIR="${PROJECT_ROOT}/build"
DMG_PATH="${BUILD_DIR}/Caker.dmg"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/dmg-resources/.background"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"
fi

echo "Creating DMG for version ${VERSION}, developer ID ${DEVELOPER_ID}"
# Vérifier que l'application existe
if [ ! -d "${PKGDIR}" ]; then
	echo "Error: Caker.app not found at ${PKGDIR}"
	echo "Please run create-pkg.sh first to build the application bundle"
	exit 1
fi

ditto "${PKGDIR}" "${BUILD_DIR}/dmg-resources/Caker.app"
cp "${PROJECT_ROOT}/.ci/dmg-resources/background.png" "${BUILD_DIR}/dmg-resources/.background/background.png"
cp "${PROJECT_ROOT}/.ci/dmg-resources/DS_Store" "${BUILD_DIR}/dmg-resources/.DS_Store"
ln -s /Applications "${BUILD_DIR}/dmg-resources/Applications"

hdiutil create \
    -volname "Caker" \
    -srcfolder "${BUILD_DIR}/dmg-resources" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
