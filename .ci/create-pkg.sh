#!/bin/bash
set -e

SNAPSHOT=$(git rev-parse --short=8 HEAD)
VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}
PKGDIR=${CURDIR}/.ci/pkg/Caker.app
popd > /dev/null

if [ -f ${CURDIR}/.env ]; then
	source ${CURDIR}/.env
fi

BUILDDIR="${CURDIR}/.build/universal/release"
RESOURCESDIR="${CURDIR}/Caker/Caker/Content"
ASSETS="${BUILDDIR}/assets"
RELEASE=1

rm -rf "${BUILDDIR}" "${PKGDIR}" "${CURDIR}/Caker-${VERSION_TAG}.pkg"

mkdir -p "${BUILDDIR}"

for FILE in Caker caked cakectl; do
	lipo -create "${CURDIR}/.build/x86_64-apple-macosx/release/$FILE" "${CURDIR}/.build/arm64-apple-macosx/release/$FILE" -output "${BUILDDIR}/$FILE"
done

source "${CURDIR}/Scripts/build.inc.sh"

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating package for version ${VERSION_TAG}, team ID ${TEAM_ID}"

pkgbuild --root .ci/pkg/ \
		--identifier com.aldunelabs.caker \
		--version ${VERSION_TAG} \
		--scripts .ci/pkg/scripts \
		--install-location "/Applications" \
		--sign "Developer ID Installer: Frederic BOLTZ (${TEAM_ID})" \
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
