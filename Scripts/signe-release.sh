#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}"
KEYCHAIN_OPTIONS=${1:-}

if [ -f ${PROJECT_ROOT}/.env ]; then
	source ${PROJECT_ROOT}/.env
fi

if [ -n "${KEYCHAIN_OPTIONS}" ]; then
	KEYCHAIN_OPTIONS="--keychain ${KEYCHAIN_OPTIONS}"
else
	KEYCHAIN_OPTIONS=
fi

BUILDDIR="${PROJECT_ROOT}/.build/release"
BINARYDIR="${PROJECT_ROOT}/.build/universal/release"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
RELEASE=1
APPSTORE=0
USE_SMAPPSERVICE=0

mkdir -p ${BINARYDIR}

for FILE in Caker caked cakectl; do
	lipo -create "${PROJECT_ROOT}/.build/x86_64-apple-macosx/release/${FILE}" "${PROJECT_ROOT}/.build/arm64-apple-macosx/release/${FILE}" -output "${BINARYDIR}/${FILE}"
done

source "${PROJECT_ROOT}/Scripts/build.inc.sh"
