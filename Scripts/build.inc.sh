SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
export VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}

rm -Rf "${PKGDIR}"
mkdir -p "${ASSETS}" "${PKGDIR}/Contents/Frameworks" "${PKGDIR}/Contents/MacOS" "${PKGDIR}/Contents/PlugIns" "${PKGDIR}/Contents/Resources" "${PKGDIR}/Contents/Resources/Icons"

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

cp -R "${BUILDDIR}/Sparkle.framework" "${PKGDIR}/Contents/Frameworks/"

for FILE in Headers PrivateHeaders Modules; do
	FILE="${PKGDIR}/Contents/Frameworks/Sparkle.framework/${FILE}"
	
	if [ -d "${FILE}" ]; then
		rm -rf "${FILE}"
	fi
done

cp -c "${BINARYDIR}/Caker" "${PKGDIR}/Contents/MacOS/Caker"
cp -c "${BINARYDIR}/caked" "${PKGDIR}/Contents/PlugIns/caked"
cp -c "${BINARYDIR}/cakectl" "${PKGDIR}/Contents/PlugIns/cakectl"
cp -c "${RESOURCESDIR}/Document.icns" "${PKGDIR}/Contents/Resources/Document.icns"
cp -c "${RESOURCESDIR}/MenuBarIcon.png" "${PKGDIR}/Contents/Resources/MenuBarIcon.png"
cp -c "${ASSETS}/AppIcon.icns" "${PKGDIR}/Contents/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${PKGDIR}/Contents/Resources/Assets.car"
cp -c "${PROJECT_ROOT}/Resources/Icons/"*.png "${PKGDIR}/Contents/Resources/Icons"
cp -c "${PROJECT_ROOT}/Resources/Caker.provisionprofile" "${PKGDIR}/Contents/embedded.provisionprofile"
cp -c "${PROJECT_ROOT}/Resources/Info.plist" "${PKGDIR}/Contents/Info.plist"

if [ -n "${SPARKLE_PUBLIC_KEY}" ]; then
	plutil -replace SUPublicEDKey -string "${SPARKLE_PUBLIC_KEY}" "${PKGDIR}/Contents/Info.plist"
fi

plutil -replace CFBundleShortVersionString -string "$(echo ${VERSION} | awk -F '[.-]' '{print tolower($1)}')" "${PKGDIR}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${PKGDIR}/Contents/Info.plist"

if [ -n "${RELEASE}" ] && [ -n "${DEVELOPER_ID}" ]; then
	echo "Build and sign release binaries for version ${VERSION}, developer ID ${DEVELOPER_ID}"

	if [ -n "${CODESIGN_REQUIREMENT}" ]; then
		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/caked/)
		echo "Using custom code signing requirement: ${REQUIREMENTS}"
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/PlugIns/caked"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/cakectl/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/PlugIns/cakectl"


		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}/Contents/Frameworks/Sparkle.framework/Versions/Current"


		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}/Contents/MacOS/Caker"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${PKGDIR}"
	else
		echo "Warning: CODESIGN_REQUIREMENT not set, skipping requirement check for code signing"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}/Contents/PlugIns/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}/Contents/PlugIns/cakectl"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}/Contents/Frameworks/Sparkle.framework/Versions/Current"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}/Contents/MacOS/Caker"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}"
	fi
else
	echo "Build unsigned debug binaries"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${PKGDIR}/Contents/PlugIns/caked"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${PKGDIR}/Contents/PlugIns/cakectl"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${PKGDIR}/Contents/Frameworks/Sparkle.framework/Versions/Current"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${PKGDIR}/Contents/MacOS/Caker"
fi
