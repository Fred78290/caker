#!/bin/bash
set -e

SNAPSHOT=$(git rev-parse --short=8 HEAD)
VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}
PKGDIR=${CURDIR}/.ci/pkg
popd > /dev/null

if [ -f ${CURDIR}/.env ]; then
	source ${CURDIR}/.env
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION_TAG}, team ID ${TEAM_ID}"

pkgbuild --root "${PKGDIR}" \
		--identifier com.aldunelabs.caker \
		--version ${VERSION_TAG} \
		--scripts "${PKGDIR}/scripts" \
		--install-location "/Applications" \
		--sign "Developer ID Installer: ${DEVELOPER_ID}" \
		${KEYCHAIN_OPTIONS} \
		"${CURDIR}/Caker-${VERSION_TAG}.pkg"

echo "Submitting package for notarization"

xcrun notarytool submit "${CURDIR}/Caker-${VERSION_TAG}.pkg" ${KEYCHAIN_OPTIONS} \
		--apple-id ${APPLE_ID} \
		--team-id ${TEAM_ID} \
		--password "${APP_PASSWORD}" \
		--wait

echo "Stapling package"

xcrun stapler staple "${CURDIR}/Caker-${VERSION_TAG}.pkg"
