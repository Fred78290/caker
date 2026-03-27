#!/bin/bash
VERSION=${VERSION_TAG:=SNAPSHOT}
set -ex
pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}
PKGDIR=${CURDIR}/.ci/pkg/Caker.app
DMGDIR=${CURDIR}/.ci/dmg
DMGFILE=${CURDIR}/Caker-${VERSION}.dmg
popd > /dev/null

if [ -f .env ]; then
	source .env
fi

echo "Creating DMG for version ${VERSION}"

# Vérifier que l'application existe
if [ ! -d "${PKGDIR}" ]; then
	echo "Error: Caker.app not found at ${PKGDIR}"
	echo "Please run create-pkg.sh first to build the application bundle"
	exit 1
fi

# Nettoyer les fichiers existants
rm -rf "${DMGDIR}" "${DMGFILE}"

# Créer le dossier temporaire pour le DMG
mkdir -p "${DMGDIR}"

# Copier l'application dans le dossier DMG
echo "Copying Caker.app to DMG folder..."
cp -R "${PKGDIR}" "${DMGDIR}/"

# Créer un lien symbolique vers Applications
echo "Creating symbolic link to Applications..."
ln -sf /Applications "${DMGDIR}/Applications"

# Signer l'application dans le dossier DMG (re-signature pour s'assurer que tout est correct)
#if [ -n "${TEAM_ID}" ]; then
#	echo "Code signing Caker.app..."
#	codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --entitlements Resources/release.entitlements --force --deep "${DMGDIR}/Caker.app"
#fi

# Créer un DMG temporaire en lecture/écriture
echo "Creating temporary DMG..."
TEMP_DMG="${DMGFILE}.temp.dmg"
hdiutil create -srcfolder "${DMGDIR}" -volname "Caker ${VERSION}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 400m "${TEMP_DMG}"

# Monter le DMG temporaire
echo "Mounting temporary DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${TEMP_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/Caker ${VERSION}"

# Attendre que le montage soit prêt
sleep 2

# Créer un dossier .background pour une éventuelle image de fond
mkdir -p "${MOUNT_POINT}/.background"

# Copier une image de fond si elle existe
if [ -f "${CURDIR}/.ci/dmg-resources/background.png" ]; then
	cp "${CURDIR}/.ci/dmg-resources/background.png" "${MOUNT_POINT}/.background/"
	BACKGROUND_SETTING="set background picture of theViewOptions to file \".background:background.png\""
else
	BACKGROUND_SETTING=""
fi

# Configurer l'apparence du DMG
echo "Configuring DMG appearance..."
osascript <<EOF
tell application "Finder"
    tell disk "Caker ${VERSION}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        ${BACKGROUND_SETTING}
        set position of item "Caker.app" of container window to {125, 175}
        set position of item "Applications" of container window to {375, 175}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sleep 2

# Démonter le DMG temporaire
echo "Unmounting temporary DMG..."
hdiutil detach "${DEVICE}"

# Créer le DMG final compressé
echo "Creating final compressed DMG..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMGFILE}"

# Nettoyer le DMG temporaire
rm -f "${TEMP_DMG}"

# Signer le DMG si possible
if [ -n "${TEAM_ID}" ]; then
	echo "Code signing DMG..."
	codesign --sign "Developer ID Application: Frederic BOLTZ (${TEAM_ID})" --options runtime --force "${DMGFILE}"
fi

# Notariser le DMG si nécessaire
if [ -n "${APPLE_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
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

# Nettoyer le dossier temporaire
rm -rf "${DMGDIR}"

echo "DMG creation completed: ${DMGFILE}"