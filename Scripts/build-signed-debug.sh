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
RELEASE=0
ARGUMENT_PARSER_ORIGINAL="https://github.com/apple/swift-argument-parser"
ARGUMENT_PARSER_MIRROR="https://github.com/Fred78290/swift-argument-parser"

if [ -f ${PROJECT_ROOT}/.env ]; then
	source ${PROJECT_ROOT}/.env
fi

sudo rm -rf "${PROJECT_ROOT}/.build" "${PROJECT_ROOT}"/*.o "${PROJECT_ROOT}"/*.d "${PROJECT_ROOT}"/*.swiftdeps "${PROJECT_ROOT}"/*.swiftdeps~

cleanup_swift_mirror() {
  /usr/bin/swift package config unset-mirror --original "${ARGUMENT_PARSER_ORIGINAL}" >/dev/null 2>&1 || true
}

trap cleanup_swift_mirror EXIT

/usr/bin/swift package config set-mirror --original "${ARGUMENT_PARSER_ORIGINAL}" --mirror "${ARGUMENT_PARSER_MIRROR}"
/usr/bin/swift package resolve
/usr/bin/swift build

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
