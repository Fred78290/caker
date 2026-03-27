#!/bin/bash
set -e

export VERSION_TAG=SNAPSHOT-$(git rev-parse --short HEAD)
VERSION=${VERSION_TAG:=SNAPSHOT}
pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}

if [ -f ${CURDIR}/.env ]; then
	source ${CURDIR}/.env

	export P12_PASSWORD
	export KEYCHAIN_PASSWORD
	export APP_PASSWORD
	export APPLE_ID
	export TEAM_ID
else
	echo "Warning: .env file not found, using default values for environment variables"
	if [ -z "$TEAM_ID" ]; then
		echo "Error: TEAM_ID environment variable not set, please set it in .env file or export it in the shell"
		exit 1
	fi
fi

pushd qcow2convert
./build.sh
popd

echo "Building version ${VERSION} with team ID ${TEAM_ID}"

/usr/bin/swift build -c release --arch x86_64
/usr/bin/swift build -c release --arch arm64

echo "Publishing version ${VERSION} with team ID ${TEAM_ID}"
if [ -f .ci/create-dist.sh ]; then
	.ci/create-dist.sh
else
	echo "Error: .ci/create-dist.sh not found, skipping publish step"
fi
popd >/dev/null