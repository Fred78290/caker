#!/bin/bash
PROJECT_ROOT=$1

PKGDIR="${PROJECT_ROOT}/dist/Caker.app"
BUILDDIR="${PROJECT_ROOT}/.build/debug"
BINARYDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
SPARKLE_PUBLIC_KEY=$(cat "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem" | tr -d '\n')

export VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}

/usr/bin/swift build -Xswiftc -diagnostic-style=llvm

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
