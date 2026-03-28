#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR="${PWD}"
PKGDIR="${CURDIR}/dist/Caker.app"
popd > /dev/null

if [ -f ${CURDIR}/.env ]; then
	source ${CURDIR}/.env
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

BUILDDIR="${CURDIR}/.build/universal/release"
RESOURCESDIR="${CURDIR}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
RELEASE=1

sudo rm -rf "${CURDIR}/.ci/pkg/Caker.app" "${CURDIR}/.build" "${CURDIR}"/*.o "${CURDIR}"/*.d "${CURDIR}"/*.swiftdeps "${CURDIR}"/*.swiftdeps~

/usr/bin/swift build -c release --arch x86_64
/usr/bin/swift build -c release --arch arm64

mkdir -p ${BUILDDIR}

for FILE in Caker caked cakectl; do
	lipo -create "${CURDIR}/.build/x86_64-apple-macosx/release/$FILE" "${CURDIR}/.build/arm64-apple-macosx/release/$FILE" -output "${BUILDDIR}/$FILE"
done

source "${CURDIR}/Scripts/build.inc.sh"
