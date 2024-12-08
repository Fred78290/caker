#!/bin/sh

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

pushd $(dirname $0) >/dev/null
CURDIR=${PWD}
popd > /dev/null

swift build
codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked

rm -Rf dist/Cake.app/
mkdir -p dist/Cake.app/Contents/MacOS dist/Cake.app/Contents/Resources
cp -c .build/debug/caked dist/Cake.app/Contents/MacOS/caked
cp -c ${CURDIR}/caker.provisionprofile dist/Cake.app/Contents/embedded.provisionprofile
cp -c ${CURDIR}/caked.plist dist/Cake.app/Contents/Info.plist
cp -c Resources/CakedAppIcon.png dist/Cake.app/Contents/Resources/AppIcon.png

dist/Cake.app/Contents/MacOS/caked "$@"
