#!/bin/bash
set -e

function cleanup() {
	security delete-keychain "${RUNNER_TEMP}/app-signing.keychain-db"
	rm -rf "${RUNNER_TEMP}"
}

export VERSION=SNAPSHOT-$(git rev-parse --short HEAD)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
DMG_PATH="${BUILD_DIR}/Caker-${VERSION}.dmg"

export RUNNER_TEMP="${PROJECT_ROOT}/tmp"
export PKGDIR="${PKGDIR:-${PROJECT_ROOT}/.ci/pkg/Caker.app}"

mkdir -p "${BUILD_DIR}" "${RUNNER_TEMP}"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"

	export P12_PASSWORD
	export KEYCHAIN_PASSWORD
	export APP_PASSWORD
	export APPLE_ID
	export TEAM_ID
	export DEVELOPER_ID
	export BUILD_CERTIFICATE_BASE64
	export CODESIGN_REQUIREMENT
	export SPARKLE_PUBLIC_KEY
	export SPARKLE_PRIVATE_KEY
	export NOTARYZATION=true
	export SETUP_KEYCHAIN=false
else
	echo "Warning: .env file not found, using default values for environment variables"
	if [ -z "${TEAM_ID}" ] || [ -z "${APPLE_ID}" ] || [ -z "$P12_PASSWORD" ] || [ -z "${KEYCHAIN_PASSWORD}" ] || [ -z "${APP_PASSWORD}" ]; then
		echo "Error: One or more required environment variables not set, please set them in .env file or export them in the shell"
		exit 1
	fi
fi

pushd qcow2convert
./build.sh
popd

if [ "${SETUP_KEYCHAIN}" == true ]; then
	trap "cleanup" EXIT
	KEYCHAIN_PATH="${RUNNER_TEMP}/app-signing.keychain-db"
	"${PROJECT_ROOT}/.ci/setup-keychain.sh" "${KEYCHAIN_PATH}"
else
	KEYCHAIN_PATH=""
fi

echo "Building version ${VERSION} with developer ID ${DEVELOPER_ID}"
"${PROJECT_ROOT}/Scripts/build-signed-release.sh" "${KEYCHAIN_PATH}"

echo "Publishing version ${VERSION} with developer ID ${DEVELOPER_ID}"
"${PROJECT_ROOT}/.ci/create-dist.sh" "${KEYCHAIN_PATH}"
"${PROJECT_ROOT}/Scripts/sparkle-sign-release.sh" "${VERSION}" "${DMG_PATH}"

popd >/dev/null