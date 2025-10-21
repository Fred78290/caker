#!/bin/bash
VERSION=${VERSION_TAG:=SNAPSHOT}

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}
PKGDIR=${CURDIR}/.ci/pkg/Caker.app
popd > /dev/null

if [ -f .env ]; then
	source .env
fi

BUILDDIR=${CURDIR}/.build/release
RESOURCESDIR=${CURDIR}/Caker/Caker/Content
ASSETS=${BUILDDIR}/assets

rm -rf ${PKGDIR} ${CURDIR}/Caker-${VERSION}.pkg

mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources ${PKGDIR}/Contents/Resources/Icons

codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/x86_64-apple-macosx/release/caker
codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/arm64-apple-macosx/release/caker

codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/x86_64-apple-macosx/release/caked
codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/arm64-apple-macosx/release/caked

codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/x86_64-apple-macosx/release/cakectl
codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force ${CURDIR}/arm64-apple-macosx/release/cakectl

lipo -create ${CURDIR}/x86_64-apple-macosx/release/caker ${CURDIR}/arm64-apple-macosx/release/caker -output ${PKGDIR}/Contents/MacOS/caker
lipo -create ${CURDIR}/x86_64-apple-macosx/release/caked ${CURDIR}/arm64-apple-macosx/release/caked -output ${PKGDIR}/Contents/MacOS/caked
lipo -create ${CURDIR}/x86_64-apple-macosx/release/cakectl ${CURDIR}/arm64-apple-macosx/release/cakectl -output ${PKGDIR}/Contents/Resources/cakectl

cp -c ${RESOURCESDIR}/Document.icns ${PKGDIR}/Contents/Resources/Document.icns
cp -c ${RESOURCESDIR}/MenuBarIcon.png ${PKGDIR}/Contents/Resources/MenuBarIcon.png
cp -c ${ASSETS}/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c ${ASSETS}/Assets.car ${PKGDIR}/Contents/Resources/Assets.car
cp -c ${CURDIR}/Resources/Icons/*.png ${PKGDIR}/Contents/Resources/Icons
cp -c ${CURDIR}/Resources/Caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/caked.plist ${PKGDIR}/Contents/Info.plist

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION}, team ID ${TEAM_ID}"

pkgbuild --root .ci/pkg/ \
		--identifier com.aldunelabs.caker \
		--version ${VERSION} \
		--scripts .ci/pkg/scripts \
		--install-location "/Library/Application Support/Caker" \
		--sign "Developer ID Installer: Frederic BOLTZ (${TEAM_ID})" \
		${KEYCHAIN_OPTIONS} \
		"${CURDIR}/Caker-${VERSION}.pkg"

echo "Submitting package for notarization"

xcrun notarytool submit "${CURDIR}/Caker-${VERSION}.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

echo "Stapling package"

xcrun stapler staple "${CURDIR}/Caker-${VERSION}.pkg"
