#!/bin/bash
if [ -f .env ]; then
	source .env
fi

VERSION=${VERSION:=SNAPSHOT}
CURDIR=${PWD}
PKGDIR=.ci/pkg/Caker.app

mkdir -p ${PKGDIR}/bin ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources

lipo -create .build/x86_64-apple-macosx/release/caked .build/arm64-apple-macosx/release/caked -output ${PKGDIR}/bin/caked
lipo -create .build/x86_64-apple-macosx/release/cakectl .build/arm64-apple-macosx/release/cakectl -output ${PKGDIR}/bin/cakectl

pushd ${PKGDIR}/Contents/MacOS >/dev/null
ln -s ../../bin/caked .
ln -s ../../bin/cakectl .
popd >/dev/null

cp -c ${CURDIR}/Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/cakectl.plist ${PKGDIR}/Contents/Info.plist
cp -c ${CURDIR}/Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

pkgbuild --root .ci/pkg/ \
		--identifier com.aldunelabs.caker \
		--version $VERSION \
		--scripts .ci/pkg/scripts \
		--install-location "/Library/Application Support/Caker" \
		--sign "Developer ID Installer: Frederic BOLTZ (${TEAM_ID})" \
		${KEYCHAIN_OPTIONS} \
		"./.ci/Caker-$VERSION.pkg"

xcrun notarytool submit "./.ci/Caker-$VERSION.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

xcrun stapler staple "./.ci/Caker-$VERSION.pkg"
