#!/bin/bash
CURDIR=$1

PKGDIR=${CURDIR}/dist/Caker.app
BUILDDIR="${CURDIR}/.build/debug"
RESOURCESDIR="${CURDIR}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
SNAPSHOT=$(git rev-parse --short=8 HEAD)

export VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}

/usr/bin/swift build -Xswiftc -diagnostic-style=llvm

codesign --sign - --entitlements Resources/dev.entitlements --force "${BUILDDIR}/Caker"
codesign --sign - --entitlements Resources/dev.entitlements --force "${BUILDDIR}/caked"
codesign --sign - --entitlements Resources/dev.entitlements --force "${BUILDDIR}/cakectl"

mkdir -p "${ASSETS}" "${PKGDIR}/Contents/MacOS" "${PKGDIR}/Contents/PlugIns" "${PKGDIR}/Contents/Resources" "${PKGDIR}/Contents/Resources/Icons"

actool "${RESOURCESDIR}/Assets.xcassets" \
	--compile "${ASSETS}" \
	--output-format human-readable-text \
	--notices --warnings \
	--export-dependency-info "${ASSETS}/assetcatalog_dependencies_thinned" \
	--output-partial-info-plist "${ASSETS}/assetcatalog_generated_info.plist_thinned" \
	--app-icon AppIcon \
	--include-all-app-icons \
	--accent-color AccentColor \
	--enable-on-demand-resources NO \
	--development-region en \
	--target-device mac \
	--minimum-deployment-target 15.0 \
	--platform macosx

cp -c "${BUILDDIR}/Caker" "${PKGDIR}/Contents/MacOS/Caker"
cp -c "${BUILDDIR}/caked" "${PKGDIR}/Contents/PlugIns/caked"
cp -c "${BUILDDIR}/cakectl" "${PKGDIR}/Contents/PlugIns/cakectl"
cp -c "${RESOURCESDIR}/Document.icns" "${PKGDIR}/Contents/Resources/Document.icns"
cp -c "${RESOURCESDIR}/MenuBarIcon.png" "${PKGDIR}/Contents/Resources/MenuBarIcon.png"
cp -c "${ASSETS}/AppIcon.icns" "${PKGDIR}/Contents/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${PKGDIR}/Contents/Resources/Assets.car"
cp -c "${CURDIR}/Resources/Icons/"*.png "${PKGDIR}/Contents/Resources/Icons"
cp -c "${CURDIR}/Resources/Caker.provisionprofile" "${PKGDIR}/Contents/embedded.provisionprofile"

envsubst < "${CURDIR}/Resources/Info.plist" > "${PKGDIR}/Contents/Info.plist"
