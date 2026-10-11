#!/bin/bash
set -e

BASE_VERSION=${BASE_VERSION:-1.0}
VERSION="${VERSION:-${BASE_VERSION}.$(git rev-list --count HEAD)}"
NOTARYZATION=${NOTARYZATION:=false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PATH="${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}"
PKG_PATH="${PKG_PATH:-${PROJECT_ROOT}/build/Caker.pkg}"

# Stage Caker.app alone in a fresh root: pkgbuild installs everything under --root into
# --install-location, so using the app's parent directory (.ci/pkg) shipped components/,
# distribution.xml, resources/ and scripts/ into /Applications next to Caker.app.
WORK_DIR="$(mktemp -d "/tmp/caker-pkg.XXXXXX")"
PKG_ROOT="${WORK_DIR}/root"
BUILD_DIR="${WORK_DIR}/components"
COMPONENT_PLIST="${WORK_DIR}/component.plist"
trap 'rm -rf "${WORK_DIR}"' EXIT

if [ ! -d "${APP_PATH}" ]; then
	echo "Error: Caker.app not found at ${APP_PATH}"
	exit 1
fi

mkdir -p "$(dirname "${PKG_PATH}")" "${PKG_ROOT}" "${BUILD_DIR}"
ditto "${APP_PATH}" "${PKG_ROOT}/Caker.app"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION}, team ID ${TEAM_ID}"

pkgbuild --analyze --root "${PKG_ROOT}" "${COMPONENT_PLIST}"
plutil -replace BundleIsRelocatable -bool NO "${COMPONENT_PLIST}"

pkgbuild ${KEYCHAIN_OPTIONS} --root "${PKG_ROOT}" \
		--component-plist "${COMPONENT_PLIST}" \
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