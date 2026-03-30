#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PROJECT_ROOT}/dist/Caker.app"

BUILDDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"

[ -f *.swiftdeps ] && sudo rm -rf ${PROJECT_ROOT}/.build ${PROJECT_ROOT}/*.o ${PROJECT_ROOT}/*.d ${PROJECT_ROOT}/*.swiftdeps ${PROJECT_ROOT}/*.swiftdeps~

set -e

/usr/bin/swift build

source "${PROJECT_ROOT}/Scripts/build.inc.sh"

exec "${PKGDIR}/Contents/PlugIns/cakectl" "$@"
