#!/bin/bash
set -e

NOTARYZATION=${NOTARYZATION:=false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PKGDIR="${PKGDIR:-${PROJECT_ROOT}/dist/Caker.app}"
DMG_PATH="${DMG_PATH:-${PROJECT_ROOT}/build/Caker.dmg}"
DMG_DIR="$(dirname "${DMG_PATH}")"

mkdir -p "${DMG_DIR}"

if [ -f "${PROJECT_ROOT}/.env" ]; then
	source "${PROJECT_ROOT}/.env"
fi

if [ -n "$1" ]; then
	KEYCHAIN_OPTIONS="--keychain $1"
else
	KEYCHAIN_OPTIONS=
fi

echo "Creating DMG, developer ID ${DEVELOPER_ID}"

# Vérifier que l'application existe
if [ ! -d "${PKGDIR}" ]; then
	echo "Error: Caker.app not found at ${PKGDIR}"
	echo "Please run create-pkg.sh first to build the application bundle"
	exit 1
fi

# Nettoyer le fichier DMG existant
rm -f "${DMG_PATH}"

if [ -f "${PROJECT_ROOT}/.ci/dmg-resources/DS_Store" ]; then
	mkdir -p "${DMG_DIR}/dmg-resources/.background"

	ditto "${PKGDIR}" "${DMG_DIR}/dmg-resources/Caker.app"

	cp "${PROJECT_ROOT}/.ci/dmg-resources/background.png" "${DMG_DIR}/dmg-resources/.background/background.png"
	cp "${PROJECT_ROOT}/.ci/dmg-resources/DS_Store" "${DMG_DIR}/dmg-resources/.DS_Store"
	ln -s /Applications "${DMG_DIR}/dmg-resources/Applications"

	hdiutil create \
		-volname "Caker" \
		-srcfolder "${DMG_DIR}/dmg-resources" \
		-ov \
		-format UDZO \
		"${DMG_PATH}"

else
	# Vérifier que create-dmg est disponible
	if ! command -v create-dmg &> /dev/null; then
		echo "Error: create-dmg is not installed"
		echo "Install it with: brew install create-dmg"
		exit 1
	fi

	# Préparer les options create-dmg
	CREATE_DMG_OPTIONS=(
		--volname "Caker"
		--window-pos 200 120
		--window-size 800 400
		--icon-size 100
		--icon "Caker.app" 200 190
		--hide-extension "Caker.app"
		--app-drop-link 600 185
	)

	# Retirer les options pour les fichiers qui n'existent pas
	if [ -f "${PROJECT_ROOT}/.ci/dmg-resources/volume.icns" ]; then
		CREATE_DMG_OPTIONS+=("--volicon" "${PROJECT_ROOT}/.ci/dmg-resources/volume.icns")
	fi

	if [ -f "${PROJECT_ROOT}/.ci/dmg-resources/background.png" ]; then
		CREATE_DMG_OPTIONS+=("--background" "${PROJECT_ROOT}/.ci/dmg-resources/background.png")
	fi

	# Créer le DMG avec create-dmg
	echo "Creating DMG with create-dmg..."
	create-dmg "${CREATE_DMG_OPTIONS[@]}" "${DMG_PATH}" "${PKGDIR}"
fi

# Signer le DMG si possible
if [ -n "${DEVELOPER_ID}" ]; then
	echo "Code signing DMG..."
	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" --options runtime --force "${DMG_PATH}"

	# Notariser le DMG si nécessaire
	if [ ${NOTARYZATION} == "true" ] && [ -n "${APPLE_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
		echo "Submitting DMG for notarization..."
		
		if [ -n "$1" ]; then
			KEYCHAIN_OPTIONS="--keychain $1"
		else
			KEYCHAIN_OPTIONS=
		fi

		# Mzmo xcrun notarytool log --apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password "${APP_PASSWORD}" 0611530c-fe18-42fa-8d27-dbe700b96684
		xcrun notarytool submit "${DMG_PATH}" ${KEYCHAIN_OPTIONS} \
				--apple-id ${APPLE_ID} \
				--team-id ${TEAM_ID} \
				--password "${APP_PASSWORD}" \
				--wait | tee /tmp/notarization.log
				
		grep "id:" /tmp/notarization.log | head -n 1 | awk '{print $2}' | xargs -I {} xcrun notarytool log --apple-id ${APPLE_ID} --team-id ${TEAM_ID} --password "${APP_PASSWORD}" {}

		echo "Stapling DMG..."
		xcrun stapler staple "${DMG_PATH}"
	fi
fi

echo "DMG creation completed: ${DMG_PATH}"