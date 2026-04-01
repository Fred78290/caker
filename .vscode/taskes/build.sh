#!/bin/bash
PROJECT_ROOT=$1

PKGDIR="${PROJECT_ROOT}/dist/Caker.app"
BUILDDIR="${PROJECT_ROOT}/.build/debug"
RESOURCESDIR="${PROJECT_ROOT}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
SPARKLE_PUBLIC_KEY=$(cat "${PROJECT_ROOT}/.sparkle/sparkle_public_key.pem" | tr -d '\n')

export VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}

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
cp -c "${PROJECT_ROOT}/Resources/Prompt.png" "${PKGDIR}/Contents/Resources/Prompt.png"
cp -c "${PROJECT_ROOT}/Resources/Icons/"*.png "${PKGDIR}/Contents/Resources/Icons"
cp -c "${PROJECT_ROOT}/Resources/Caker.provisionprofile" "${PKGDIR}/Contents/embedded.provisionprofile"

cp "${PROJECT_ROOT}/Resources/Info.plist" "${PKGDIR}/Contents/Info.plist"

plutil -replace SUPublicEDKey -string "${SPARKLE_PUBLIC_KEY}" "${PKGDIR}/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$(echo ${VERSION} | awk -F '[.-]' '{print tolower($1)}')" "${PKGDIR}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${PKGDIR}/Contents/Info.plist"
