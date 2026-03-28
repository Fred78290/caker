#!/bin/bash
set -e

function cleanup() {
	security delete-keychain "${RUNNER_TEMP}/app-signing.keychain-db"
	rm -rf "${RUNNER_TEMP}"
}

export VERSION_TAG=SNAPSHOT-$(git rev-parse --short HEAD)

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR="${PWD}"
popd > /dev/null

export RUNNER_TEMP="${CURDIR}/tmp"
export PKGDIR="${CURDIR}/.ci/pkg/Caker.app"

mkdir -p "${RUNNER_TEMP}"

if [ -f "${CURDIR}/.env" ]; then
	source "${CURDIR}/.env"

	export P12_PASSWORD
	export KEYCHAIN_PASSWORD
	export APP_PASSWORD
	export APPLE_ID
	export TEAM_ID
	export DEVELOPER_ID
	export BUILD_CERTIFICATE_BASE64
	export CODESIGN_REQUIREMENT
else
	echo "Warning: .env file not found, using default values for environment variables"
	if [ -z "$TEAM_ID" ] || [ -z "$APPLE_ID" ] || [ -z "$P12_PASSWORD" ] || [ -z "$KEYCHAIN_PASSWORD" ] || [ -z "$APP_PASSWORD" ]; then
		echo "Error: One or more required environment variables not set, please set them in .env file or export them in the shell"
		exit 1
	fi
fi

pushd qcow2convert
./build.sh
popd

echo "Building version ${VERSION_TAG} with developer ID ${DEVELOPER_ID}"

"${CURDIR}/.ci/setup-keychain.sh" "${RUNNER_TEMP}/app-signing.keychain-db"
"${CURDIR}/Scripts/build-signed-release.sh" "${RUNNER_TEMP}/app-signing.keychain-db"

trap "cleanup" EXIT

echo "Publishing version ${VERSION_TAG} with developer ID ${DEVELOPER_ID}"
if [ -f "${CURDIR}/.ci/create-dist.sh" ]; then
	"${CURDIR}/.ci/create-dist.sh" "${RUNNER_TEMP}/app-signing.keychain-db"
else
	echo "Error: .ci/create-dist.sh not found, skipping publish step"
fi

popd >/dev/null