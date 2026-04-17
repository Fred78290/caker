#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PKGDIR="${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}"
BUILDDIR="${PROJECT_ROOT}/.build/debug"
BINARYDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)

sudo rm -rf "${PROJECT_ROOT}/.build" "${PROJECT_ROOT}"/*.o "${PROJECT_ROOT}"/*.d "${PROJECT_ROOT}"/*.swiftdeps "${PROJECT_ROOT}"/*.swiftdeps~

/usr/bin/swift package resolve
/usr/bin/swift package config set-mirror --original https://github.com/apple/swift-argument-parser --mirror https://github.com/Fred78290/swift-argument-parser
/usr/bin/swift build

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
