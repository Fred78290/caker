#!/bin/bash
set -e

SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}
NOTARYZATION=${NOTARYZATION:=false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR=$(dirname "${PKGDIR:-${PROJECT_ROOT}/.ci/pkg/Caker.app}")
PKG_PATH="${PKG_PATH:-${PROJECT_ROOT}/build/Caker-${VERSION}.pkg}"

mkdir -p "$(dirname "${PKG_PATH}")"

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
		"${PKG_PATH}"

if [ ${NOTARYZATION} == true ]; then
		echo "Notarization enabled, will submit package to Apple for notarization"
		echo "Submitting package for notarization"

		xcrun notarytool submit "${PKG_PATH}" ${KEYCHAIN_OPTIONS} \
				--apple-id ${APPLE_ID} \
				--team-id ${TEAM_ID} \
				--password "${APP_PASSWORD}" \
				--wait

		echo "Stapling package"

		xcrun stapler staple "${PKG_PATH}"
fi