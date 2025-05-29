#!/bin/bash
swift build

codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/cakectl

PKGDIR=./dist/Caker.app

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/caked ${PKGDIR}/Contents/MacOS/caked
cp -c .build/debug/cakectl ${PKGDIR}/Contents/Resources/cakectl
cp -c Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c Resources/Document.icns ${PKGDIR}/Contents/Resources/Document.icns

BIN_PATH=$(swift build --show-bin-path)
BIN_PATH=${PKGDIR}/Contents/MacOS

OCI_IMAGE=ocis://ghcr.io/cirruslabs/macos-sequoia-vanilla:latest
DISK_SIZE=120
CMD="caked "
BUILD_OPTIONS="--display-refit --cpus=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

${BIN_PATH}/${CMD} delete sequoia
${BIN_PATH}/${CMD} build sequoia ${BUILD_OPTIONS} ${OCI_IMAGE}
