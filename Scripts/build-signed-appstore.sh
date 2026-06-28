#!/bin/bash

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGDIR="${PKGDIR:-${PROJECT_ROOT}/appstore/Caker.app}"
KEYCHAIN_OPTIONS=${1:-}

if [ -f ${PROJECT_ROOT}/.env ]; then
	source ${PROJECT_ROOT}/.env
fi

if [ -n "${KEYCHAIN_OPTIONS}" ]; then
	KEYCHAIN_OPTIONS="--keychain ${KEYCHAIN_OPTIONS}"
else
	KEYCHAIN_OPTIONS=
fi

BUILDDIR="${PROJECT_ROOT}/.appstore/release"
BINARYDIR="${PROJECT_ROOT}/.appstore/universal/release"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
RELEASE=1
APPSTORE=1
USE_SMAPPSERVICE=1
BASE_VERSION=${BASE_VERSION:-1.0}
VERSION="${VERSION:-${BASE_VERSION}.$(git rev-list --count HEAD)}"

#sudo rm -rf "${PROJECT_ROOT}/.appstore" "${PROJECT_ROOT}"/*.o "${PROJECT_ROOT}"/*.d "${PROJECT_ROOT}"/*.swiftdeps "${PROJECT_ROOT}"/*.swiftdeps~
sudo rm -rf "${PROJECT_ROOT}/.ci/pkg/Caker.app"

cleanup_swift_package_mirror() {
	/usr/bin/swift package config unset-mirror --original https://github.com/apple/swift-argument-parser || true
}
trap cleanup_swift_package_mirror EXIT

/usr/bin/swift package config set-mirror --original https://github.com/apple/swift-argument-parser --mirror https://github.com/Fred78290/swift-argument-parser
/usr/bin/swift package resolve

jq '(.pins[] | select(.identity == "swift-argument-parser")) |= (
  .location = "https://github.com/Fred78290/swift-argument-parser" |
  .state.revision = "d554955e8c280aa4c4a05a039a968f0205656e77"
)' Package.resolved > Package.resolved.tmp && mv Package.resolved.tmp Package.resolved

/usr/bin/swift build -c release --arch x86_64 --build-path "${PROJECT_ROOT}/.appstore/x86_64-apple-macosx" -Xswiftc -D -Xswiftc USE_SMAPPSERVICE -Xswiftc -D -Xswiftc APPSTORE -Xswiftc -D -Xswiftc USE_VIRTUAL_INSTALL_BACKEND
/usr/bin/swift build -c release --arch arm64 --build-path "${PROJECT_ROOT}/.appstore/arm64-apple-macosx" -Xswiftc -D -Xswiftc USE_SMAPPSERVICE -Xswiftc -D -Xswiftc APPSTORE -Xswiftc -D -Xswiftc USE_VIRTUAL_INSTALL_BACKEND

mkdir -p ${BINARYDIR}

for FILE in Caker caked cakectl; do
	lipo -create "${PROJECT_ROOT}/.appstore/x86_64-apple-macosx/release/${FILE}" "${PROJECT_ROOT}/.appstore/arm64-apple-macosx/release/${FILE}" -output "${BINARYDIR}/${FILE}"
done

source "${PROJECT_ROOT}/Scripts/build.inc.sh"

OUTDIR="${PROJECT_ROOT}/appstore"
PKGNAME="${PKGNAME:-Caker.pkg}"
PKGPATH="${PKGPATH:-${OUTDIR}/${PKGNAME}}"

productbuild ${KEYCHAIN_OPTIONS} \
	--sign "3rd Party Mac Developer Installer: ${DEVELOPER_ID}" \
	--component "${OUTDIR}/Caker.app" /Applications \
	"${PKGPATH}"
