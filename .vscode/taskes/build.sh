#!/bin/bash
PROJECT_ROOT=$1

PKGDIR="${PROJECT_ROOT}/dist/Caker.app"
BUILDDIR="${PROJECT_ROOT}/.build/debug"
BINARYDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
SPARKLE_PUBLIC_KEY=$(cat "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem" | tr -d '\n')

export BASE_VERSION=${BASE_VERSION:-1.0}
export VERSION="${VERSION:-${BASE_VERSION}.$(git rev-list --count HEAD)}"

/usr/bin/swift build -Xswiftc -diagnostic-style=llvm -Xswiftc -D -Xswiftc SPARKLE

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
