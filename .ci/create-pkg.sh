#!/bin/bash
if [ -f .env ]; then
	source .env
fi

VERSION=${VERSION:=SNAPSHOT}

lipo -create .build/x86_64-apple-macosx/release/tarthelper .build/arm64-apple-macosx/release/tarthelper -output .ci/pkg/tarthelper
lipo -create .build/x86_64-apple-macosx/release/tartctl .build/arm64-apple-macosx/release/tartctl -output .ci/pkg/tartctl

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

pkgbuild --root .ci/pkg/ \
		--identifier com.aldunelabs.tarthelper \
		--version $VERSION \
		--scripts .ci/pkg/scripts \
		--install-location "/Library/Application Support/TartHelper" \
		--sign "Developer ID Installer: Frederic BOLTZ (${TEAM_ID})" \
		${KEYCHAIN_OPTIONS} \
		"./.ci/TartHelper-$VERSION.pkg"

xcrun notarytool submit "./.ci/TartHelper-$VERSION.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

xcrun stapler staple "./.ci/TartHelper-$VERSION.pkg"
