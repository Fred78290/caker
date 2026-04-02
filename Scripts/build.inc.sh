SNAPSHOT=$(date +%Y.%m.%d)-$(git rev-parse --short=8 HEAD)
export VERSION=${VERSION:=SNAPSHOT-${SNAPSHOT}}

CAKER_APP="${PKGDIR}/Contents"
CAKED_APP="${CAKER_APP}/PlugIns/caked.app/Contents"

rm -Rf "${PKGDIR}"
mkdir -p "${ASSETS}" "${CAKER_APP}/Frameworks" \
	"${CAKER_APP}/MacOS" \
	"${CAKER_APP}/Resources" \
	"${CAKER_APP}/Resources/Icons" \
	"${CAKER_APP}/PlugIns" \
	\
	"${CAKED_APP}/Resources" \
	"${CAKED_APP}/MacOS"

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

SPARKLE_FRAMEWORK="${CAKER_APP}/Frameworks/Sparkle.framework"

cp -R "${BUILDDIR}/Sparkle.framework" "${CAKER_APP}/Frameworks/"

for FILE in Headers PrivateHeaders Modules Versions/Current/XPCServices/Downloader.xpc; do
	FILE="${SPARKLE_FRAMEWORK}/${FILE}"
	
	if [ -d "${FILE}" ]; then
		rm -rf "${FILE}"
	fi
done

cp -c "${BINARYDIR}/Caker" "${CAKER_APP}/MacOS/Caker"
cp -c "${BINARYDIR}/cakectl" "${CAKED_APP}/MacOS/cakectl"
cp -c "${BINARYDIR}/caked" "${CAKED_APP}/MacOS/caked"

cp -c "${RESOURCESDIR}/Document.icns" "${CAKER_APP}/Resources/Document.icns"
cp -c "${RESOURCESDIR}/MenuBarIcon.png" "${CAKER_APP}/Resources/MenuBarIcon.png"

cp -c "${ASSETS}/AppIcon.icns" "${CAKER_APP}/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${CAKER_APP}/Resources/Assets.car"

cp -c "${PROJECT_ROOT}/Resources/Prompt.png" "${CAKER_APP}/Resources/Prompt.png"
cp -c "${PROJECT_ROOT}/Resources/Icons/"*.png "${CAKER_APP}/Resources/Icons"
cp -c "${PROJECT_ROOT}/Resources/embedded.provisionprofile" "${CAKER_APP}/embedded.provisionprofile"
cp -c "${PROJECT_ROOT}/Resources/Info.plist" "${CAKER_APP}/Info.plist"

cp -c "${ASSETS}/AppIcon.icns" "${CAKED_APP}/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${CAKED_APP}/Resources/Assets.car"
cp -c "${PROJECT_ROOT}/Resources/caked.plist" "${CAKED_APP}/Info.plist"
cp -c "${PROJECT_ROOT}/Resources/embedded.provisionprofile" "${CAKED_APP}/embedded.provisionprofile"

if [ -n "${SPARKLE_PUBLIC_KEY}" ]; then
	plutil -replace SUPublicEDKey -string "${SPARKLE_PUBLIC_KEY}" "${CAKER_APP}/Info.plist"
fi

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CAKER_APP}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CAKER_APP}/Info.plist"

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CAKED_APP}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CAKED_APP}/Info.plist"

if [ -n "${RELEASE}" ] && [ -n "${DEVELOPER_ID}" ]; then
	echo "Build and sign release binaries for version ${VERSION}, developer ID ${DEVELOPER_ID}"

	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--force "${SPARKLE_FRAMEWORK}/Versions/Current/XPCServices/Installer.xpc"

	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--force "${SPARKLE_FRAMEWORK}/Versions/Current/Updater.app"

	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--force "${SPARKLE_FRAMEWORK}/Versions/Current/Autoupdate"

	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--force "${SPARKLE_FRAMEWORK}"

	if [ -n "${CODESIGN_REQUIREMENT}" ]; then
		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/cakectl/)
		echo "Using custom code signing requirement: ${REQUIREMENTS}"
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${CAKED_APP}/MacOS/cakectl"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${CAKED_APP}/MacOS/caked"

		REQUIREMENTS=$(echo -n "${CODESIGN_REQUIREMENT}"|sed s/__IDENTIFIER__/com.aldunelabs.caker/)
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--requirement="${REQUIREMENTS}" \
			--force "${CAKER_APP}/MacOS/Caker"

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
			--force "${CAKED_APP}/MacOS/cakectl"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${CAKED_APP}/MacOS/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${CAKER_APP}/MacOS/Caker"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--entitlements "${PROJECT_ROOT}/Resources/release.entitlements" \
			--force "${PKGDIR}"
	fi
else
	echo "Build unsigned debug binaries"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${CAKED_APP}/MacOS/cakectl"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${CAKED_APP}/MacOS/caked"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${CAKER_APP}/Frameworks/Sparkle.framework/Versions/Current"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/dev.entitlements" --force "${CAKER_APP}/MacOS/Caker"
fi
