#!/bin/bash
set -e

SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}
NOTARYZATION=${NOTARYZATION:=false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR=$(dirname "${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}")
PKG_PATH="${PKG_PATH:-${PROJECT_ROOT}/build/Caker.pkg}"
BUILD_DIR="${PROJECT_ROOT}/.ci/pkg/components"

mkdir -p "$(dirname "${PKG_PATH}")"
mkdir -p "${BUILD_DIR}"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION}, team ID ${TEAM_ID}"

pkgbuild --analyze --root "${PKGDIR}" "/tmp/standalone.plist"
plutil -replace BundleIsRelocatable -bool NO "/tmp/standalone.plist"

pkgbuild ${KEYCHAIN_OPTIONS} --root "${PKGDIR}" \
		--component-plist "/tmp/standalone.plist" \
		--identifier com.aldunelabs.caker \
		--version ${VERSION} \
		--scripts "${PROJECT_ROOT}/.ci/pkg/scripts" \
		--install-location "/Applications" \
		"${BUILD_DIR}/Caker.pkg"

productbuild ${KEYCHAIN_OPTIONS} \
	--identifier com.aldunelabs.caker \
	--distribution "${PROJECT_ROOT}/.ci/pkg/distribution.xml" \
	--resources "${PROJECT_ROOT}/.ci/pkg/resources" \
	--package-path "${BUILD_DIR}" \
	--sign "Developer ID Installer: ${DEVELOPER_ID}" \
	"${PKG_PATH}"

if [ ${NOTARYZATION} == true ]; then
		echo "Notarization enabled, will submit package to Apple for notarization"
		echo "Submitting package for notarization"

		xcrun notarytool submit "${PKG_PATH}" ${KEYCHAIN_OPTIONS} \
				--apple-id ${APPLE_ID} \
				--team-id ${TEAM_ID} \
				--password "${APP_PASSWORD}" \
				--wait | tee /tmp/notarization.log
				
		grep "id:" /tmp/notarization.log | head -n 1 | awk '{print $2}' | xargs -I {} xcrun notarytool log --apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password "${APP_PASSWORD}" {}

		echo "Stapling package"
		xcrun stapler staple "${PKG_PATH}"
fi