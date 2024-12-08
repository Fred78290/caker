#!/bin/bash
CURDIR=$1

swift build --product caked -Xswiftc -diagnostic-style=llvm

codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked

PKGDIR=${CURDIR}/dist/Caker.app

mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/caked ${PKGDIR}/Contents/MacOS/caked
cp -c ${CURDIR}/Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c ${CURDIR}/Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png
