SNAPSHOT=$(git rev-parse --short=8 HEAD)
export VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}

rm -Rf "${PKGDIR}"
mkdir -p "${ASSETS}" "${PKGDIR}/Contents/MacOS" "${PKGDIR}/Contents/PlugIns" "${PKGDIR}/Contents/Resources" "${PKGDIR}/Contents/Resources/Icons"

actool "${RESOURCESDIR}/Assets.xcassets" \
	--compile "${ASSETS}" \
	--output-format human-readable-text \
	--notices --warnings \
	--export-dependency-info "${ASSETS}/assetcatalog_dependencies_thinned" \
	--output-partial-info-plist "${ASSETS}/assetcatalog_generated_info.plist_thinned" \
	--app-icon AppIcon \
	--include-all-app-icons \
	--accent-color AccentColor \
	--enable-on-demand-resources NO \
	--development-region en \
	--target-device mac \
	--minimum-deployment-target 15.0 \
	--platform macosx

cp -c "${BUILDDIR}/Caker" "${PKGDIR}/Contents/MacOS/Caker"
cp -c "${BUILDDIR}/caked" "${PKGDIR}/Contents/PlugIns/caked"
cp -c "${BUILDDIR}/cakectl" "${PKGDIR}/Contents/PlugIns/cakectl"
cp -c "${RESOURCESDIR}/Document.icns" "${PKGDIR}/Contents/Resources/Document.icns"
cp -c "${RESOURCESDIR}/MenuBarIcon.png" "${PKGDIR}/Contents/Resources/MenuBarIcon.png"
cp -c "${ASSETS}/AppIcon.icns" "${PKGDIR}/Contents/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${PKGDIR}/Contents/Resources/Assets.car"
cp -c "${CURDIR}/Resources/Icons/"*.png "${PKGDIR}/Contents/Resources/Icons"
cp -c "${CURDIR}/Resources/Caker.provisionprofile" "${PKGDIR}/Contents/embedded.provisionprofile"

envsubst < "${CURDIR}/Resources/Info.plist" > "${PKGDIR}/Contents/Info.plist"

if [ -n "${RELEASE}" ] && [ -n "${DEVELOPER_ID}" ]; then
	echo "Build and sign release binaries for version ${VERSION_TAG}, developer ID ${DEVELOPER_ID}"

	if [ -n "${CODESIGN_REQUIREMENT}" ]; then
		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/caked/)
		echo "Using custom code signing requirement: ${REQUIREMENTS}"
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/PlugIns/caked"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/cakectl/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/PlugIns/cakectl"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/MacOS/Caker"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--entitlements Resources/release.entitlements \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}"
	else
		echo "Warning: CODESIGN_REQUIREMENT not set, skipping requirement check for code signing"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--force "${PKGDIR}/Contents/PlugIns/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--force "${PKGDIR}/Contents/PlugIns/cakectl"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements Resources/release.entitlements \
			--force "${PKGDIR}/Contents/MacOS/Caker"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--entitlements Resources/release.entitlements \
			--force "${PKGDIR}"
	fi
else
	echo "Build unsigned debug binaries"
	codesign --sign - --entitlements Resources/dev.entitlements --force "${PKGDIR}/Contents/PlugIns/caked"
	codesign --sign - --entitlements Resources/dev.entitlements --force "${PKGDIR}/Contents/PlugIns/cakectl"
	codesign --sign - --entitlements Resources/dev.entitlements --force "${PKGDIR}/Contents/MacOS/Caker"
fi
