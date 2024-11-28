#!/bin/bash
if [ -f .env ]; then
	source .env
fi

VERSION=${VERSION:=SNAPSHOT}

lipo -create .build/x86_64-apple-macosx/release/caked .build/arm64-apple-macosx/release/caked -output .ci/pkg/caked
lipo -create .build/x86_64-apple-macosx/release/cakectl .build/arm64-apple-macosx/release/cakectl -output .ci/pkg/cakectl

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
