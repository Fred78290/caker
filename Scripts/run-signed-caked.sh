#!/bin/sh

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

pushd "$(dirname $0)/.." >/dev/null
PKGDIR=${PWD}/dist/Caker.app
popd > /dev/null

[ -f *.swiftdeps ] && sudo rm -rf .build *.o *.d *.swiftdeps *.swiftdeps~

swift build
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/cakectl

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/caked ${PKGDIR}/Contents/MacOS/caked
cp -c .build/debug/cakectl ${PKGDIR}/Contents/Resources/cakectl
cp -c Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png

exec ${PKGDIR}/Contents/MacOS/caked "$@"
