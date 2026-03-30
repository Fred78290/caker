#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PROJECT_ROOT}/dist/Caker.app"

BUILDDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"

/usr/bin/swift build

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
OCI_IMAGE=ocis://ghcr.io/cirruslabs/ubuntu:latest
DISK_SIZE=20
CMD="${PKGDIR}/Contents/PlugIns/caked"
BUILD_OPTIONS="--display-refit --cpu=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

"${CMD}" delete ubuntu
"${CMD}" build ubuntu ${BUILD_OPTIONS} ${OCI_IMAGE}
