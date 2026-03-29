#!/bin/bash
set -e

SNAPSHOT=$(git rev-parse --short=8 HEAD)
VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}
NOTARYZATION=${NOTARYZATION:=false}

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR="${PWD}"
PKGDIR="${PKGDIR:-${CURDIR}/.ci/pkg/}"/Caker.app
DMGFILE="${CURDIR}/Caker-${VERSION_TAG}.dmg"
popd > /dev/null

if [ -f "${CURDIR}/.env" ]; then
	source "${CURDIR}/.env"
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating DMG for version ${VERSION_TAG}, developer ID ${DEVELOPER_ID}"

# Vérifier que l'application existe
if [ ! -d "${PKGDIR}" ]; then
	echo "Error: Caker.app not found at ${PKGDIR}"
	echo "Please run create-pkg.sh first to build the application bundle"
	exit 1
fi

# Vérifier que create-dmg est disponible
if ! command -v create-dmg &> /dev/null; then
	echo "Error: create-dmg is not installed"
	echo "Install it with: brew install create-dmg"
	exit 1
fi

# Nettoyer le fichier DMG existant
rm -f "${DMGFILE}"

# Préparer les options create-dmg
CREATE_DMG_OPTIONS=(
	--volname "Caker ${VERSION_TAG}"
	--window-pos 200 120
	--window-size 800 400
	--icon-size 100
	--icon "Caker.app" 200 190
	--hide-extension "Caker.app"
	--app-drop-link 600 185
)

# Retirer les options pour les fichiers qui n'existent pas
if [ -f "${CURDIR}/.ci/dmg-resources/volume.icns" ]; then
	CREATE_DMG_OPTIONS+=("--volicon" "${CURDIR}/.ci/dmg-resources/volume.icns")
fi

if [ -f "${CURDIR}/.ci/dmg-resources/background.png" ]; then
	CREATE_DMG_OPTIONS+=("--background" "${CURDIR}/.ci/dmg-resources/background.png")
fi

# Créer le DMG avec create-dmg
echo "Creating DMG with create-dmg..."
create-dmg "${CREATE_DMG_OPTIONS[@]}" "${DMGFILE}" "${PKGDIR}"

# Signer le DMG si possible
if [ -n "${DEVELOPER_ID}" ]; then
	echo "Code signing DMG..."
	codesign --sign "Developer ID Application: ${DEVELOPER_ID}" --options runtime --force "${DMGFILE}"

	# Notariser le DMG si nécessaire
	if [ ${NOTARYZATION} == "true" ] && [ -n "${APPLE_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
		echo "Submitting DMG for notarization..."
		
		if [ -n "$1" ]; then
			KEYCHAIN_OPTIONS="--keychain $1"
		else
			KEYCHAIN_OPTIONS=
		fi

		# Mzmo xcrun notarytool log --apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password "${APP_PASSWORD}" 0611530c-fe18-42fa-8d27-dbe700b96684
		xcrun notarytool submit "${DMGFILE}" ${KEYCHAIN_OPTIONS} \
				--apple-id ${APPLE_ID} \
				--team-id ${TEAM_ID} \
				--password "${APP_PASSWORD}" \
				--wait
		
		echo "Stapling DMG..."
		xcrun stapler staple "${DMGFILE}"
	fi
fi

echo "DMG creation completed: ${DMGFILE}"