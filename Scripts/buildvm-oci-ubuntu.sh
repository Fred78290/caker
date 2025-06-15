#!/bin/bash
swift build

pushd "$(dirname $0)/.." >/dev/null
PKGDIR=${PWD}/dist/Caker.app
popd > /dev/null

codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caker
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/cakectl

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/caker ${PKGDIR}/Contents/MacOS/caker
cp -c .build/debug/caked ${PKGDIR}/Contents/MacOS/caked
cp -c .build/debug/cakectl ${PKGDIR}/Contents/Resources/cakectl
cp -c Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c Resources/Document.icns ${PKGDIR}/Contents/Resources/Document.icns

BIN_PATH=$(swift build --show-bin-path)
BIN_PATH=${PKGDIR}/Contents/MacOS
OCI_IMAGE=ocis://ghcr.io/cirruslabs/ubuntu:latest
DISK_SIZE=20
CMD="caked "
BUILD_OPTIONS="--display-refit --cpu=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

${BIN_PATH}/${CMD} delete ubuntu
${BIN_PATH}/${CMD} build ubuntu ${BUILD_OPTIONS} ${OCI_IMAGE}
