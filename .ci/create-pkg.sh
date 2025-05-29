#!/bin/bash
VERSION=${VERSION_TAG:=SNAPSHOT}
CURDIR=${PWD}
PKGDIR=.ci/pkg/Caker.app

if [ -f .env ]; then
	source .env
fi

rm -rf ${PKGDIR} ./.ci/Caker-$VERSION.pkg

mkdir -p ${PKGDIR}/bin ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources

codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force .build/x86_64-apple-macosx/release/caked
codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force .build/arm64-apple-macosx/release/caked

codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force .build/x86_64-apple-macosx/release/cakectl
codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force .build/arm64-apple-macosx/release/cakectl

lipo -create .build/x86_64-apple-macosx/release/caked .build/arm64-apple-macosx/release/caked -output ${PKGDIR}/Contents/MacOS/caked
lipo -create .build/x86_64-apple-macosx/release/cakectl .build/arm64-apple-macosx/release/cakectl -output ${PKGDIR}/Contents/Resources/cakectl

cp -c ${CURDIR}/Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c ${CURDIR}/Resources/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c ${CURDIR}/Resources/Document.icns ${PKGDIR}/Contents/Resources/Document.icns

#codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force .ci/pkg/Caker.app

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version $VERSION, team ID ${TEAM_ID}"

pkgbuild --root .ci/pkg/ \
		--identifier com.aldunelabs.caker \
		--version $VERSION \
		--scripts .ci/pkg/scripts \
		--install-location "/Library/Application Support/Caker" \
		--sign "Developer ID Installer: Frederic BOLTZ (${TEAM_ID})" \
		${KEYCHAIN_OPTIONS} \
		"./.ci/Caker-$VERSION.pkg"

echo "Submitting package for notarization"

xcrun notarytool submit "./.ci/Caker-$VERSION.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

echo "Stapling package"

xcrun stapler staple "./.ci/Caker-$VERSION.pkg"
