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

BUILDDIR="${CURDIR}/.build/universal/release"
RESOURCESDIR="${CURDIR}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
RELEASE=1

sudo rm -rf "${CURDIR}/.build" "${CURDIR}"/*.o "${CURDIR}"/*.d "${CURDIR}"/*.swiftdeps "${CURDIR}"/*.swiftdeps~

/usr/bin/swift build -c release --arch x86_64
/usr/bin/swift build -c release --arch arm64

mkdir -p ${BUILDDIR}

lipo -create ${CURDIR}/.build/x86_64-apple-macosx/release/Caker ${CURDIR}/.build/arm64-apple-macosx/release/Caker -output ${BUILDDIR}/Caker
lipo -create ${CURDIR}/.build/x86_64-apple-macosx/release/caked ${CURDIR}/.build/arm64-apple-macosx/release/caked -output ${BUILDDIR}/caked
lipo -create ${CURDIR}/.build/x86_64-apple-macosx/release/cakectl ${CURDIR}/.build/arm64-apple-macosx/release/cakectl -output ${BUILDDIR}/cakectl

source "${CURDIR}/Scripts/build.inc.sh"
