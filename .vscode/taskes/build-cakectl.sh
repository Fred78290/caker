#!/bin/bash
CURDIR=$1

/usr/bin/swift build --product cakectl -Xswiftc -diagnostic-style=llvm

codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/cakectl

PKGDIR=${CURDIR}/dist/Caker.app

mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources

cp -c .build/debug/cakectl ${PKGDIR}/Contents/MacOS/cakectl
cp -c ${CURDIR}/Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/cakectl.plist ${PKGDIR}/Contents/Info.plist
cp -c ${CURDIR}/Resources/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c ${CURDIR}/Resources/Document.icns ${PKGDIR}/Contents/Resources/Document.icns
