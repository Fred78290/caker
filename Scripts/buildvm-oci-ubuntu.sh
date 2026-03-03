#!/bin/bash
pushd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null
CURDIR="${PWD}"
PKGDIR="${CURDIR}/dist/Caker.app"
popd > /dev/null

BUILDDIR="${CURDIR}/.build/debug"
RESOURCESDIR="${CURDIR}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"

/usr/bin/swift build

source "${CURDIR}/Scripts/build.inc.sh"
OCI_IMAGE=ocis://ghcr.io/cirruslabs/ubuntu:latest
DISK_SIZE=20
CMD="${PKGDIR}/Contents/PlugIns/caked"
BUILD_OPTIONS="--display-refit --cpu=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

"${CMD}" delete ubuntu
"${CMD}" build ubuntu ${BUILD_OPTIONS} ${OCI_IMAGE}
