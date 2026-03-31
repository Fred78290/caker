#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"

mkdir -p "${BUILD_DIR}"

SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}
PKGDIR="${PKGDIR:-${PROJECT_ROOT}/.ci/pkg}"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION}, team ID ${TEAM_ID}"

pkgbuild --root "${PKGDIR}" \
		--identifier com.aldunelabs.caker \
		--version ${VERSION} \
		--scripts "${PROJECT_ROOT}/.ci/pkg/scripts" \
		--install-location "/Applications" \
		--sign "Developer ID Installer: ${DEVELOPER_ID}" \
		${KEYCHAIN_OPTIONS} \
		"${PROJECT_ROOT}/build/Caker-${VERSION}.pkg"

echo "Submitting package for notarization"

xcrun notarytool submit "${PROJECT_ROOT}/build/Caker-${VERSION}.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

echo "Stapling package"

xcrun stapler staple "${PROJECT_ROOT}/build/Caker-${VERSION}.pkg"
