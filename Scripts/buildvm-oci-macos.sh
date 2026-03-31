#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PROJECT_ROOT}/dist/Caker.app"

BUILDDIR="${PROJECT_ROOT}/.build/debug"
BINARYDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"

/usr/bin/swift build

source "${PROJECT_ROOT}/Scripts/build.inc.sh"

OCI_IMAGE=ocis://ghcr.io/cirruslabs/macos-sequoia-vanilla:latest
DISK_SIZE=120
CMD="${PKGDIR}/Contents/PlugIns/caked"
BUILD_OPTIONS="--display-refit --cpus=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

"${CMD}" delete sequoia
"${CMD}" build sequoia ${BUILD_OPTIONS} ${OCI_IMAGE}
