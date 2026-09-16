#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PROJECT_ROOT}/dist/Caker.app"

BUILDDIR="${PROJECT_ROOT}/.debug/debug"
BINARYDIR="${PROJECT_ROOT}/.debug/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"

[ -f *.swiftdeps ] && sudo rm -rf ${PROJECT_ROOT}/.debug ${PROJECT_ROOT}/*.o ${PROJECT_ROOT}/*.d ${PROJECT_ROOT}/*.swiftdeps ${PROJECT_ROOT}/*.swiftdeps~

set -e

/usr/bin/swift build -c debug \
	-Xswiftc -D -Xswiftc USE_SMAPPSERVICE \
	-Xswiftc -D -Xswiftc SPARKLE \
	-Xswiftc -D -Xswiftc USE_VIRTUAL_INSTALL_BACKEND \
	--arch $(arch) --build-path "${PROJECT_ROOT}/.debug/$(arch)-apple-macosx"

source "${PROJECT_ROOT}/Scripts/build.inc.sh"

exec "${PKGDIR}/Contents/PlugIns/caked.bundle/Contents/MacOS/cakectl" "$@"
