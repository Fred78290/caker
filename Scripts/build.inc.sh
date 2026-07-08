BASE_VERSION=${BASE_VERSION:-1.0}
VERSION="${VERSION:-${BASE_VERSION}.$(git rev-list --count HEAD)}"
BUILDRELEASE=${BUILDRELEASE:-false}
SPARKLE_PUBLIC_KEY=${SPARKLE_PUBLIC_KEY:-}
DEVELOPER_ID=${DEVELOPER_ID:-}
CODESIGN_REQUIREMENT=${CODESIGN_REQUIREMENT:-}
RELEASE=${RELEASE:-0}
APPSTORE=${APPSTORE:-0}
USE_SMAPPSERVICE=${USE_SMAPPSERVICE:-0}

CAKER_APP="${PKGDIR}/Contents"
CAKED_APP="${CAKER_APP}/PlugIns/caked.bundle/Contents"
CAKECTL_APP="${CAKER_APP}/PlugIns/cakectl.bundle/Contents"

pushd "${PROJECT_ROOT}/webui" > /dev/null
npm install
npm ci --no-audit --no-fund
npm run build

pushd ${PROJECT_ROOT}/webui/dist > /dev/null
zip -r ../webui.zip .
popd > /dev/null

popd > /dev/null

rm -Rf "${PKGDIR}"
mkdir -p "${ASSETS}" "${CAKER_APP}/Frameworks" \
	"${CAKER_APP}/MacOS" \
	"${CAKER_APP}/Resources" \
	"${CAKER_APP}/Resources/Icons" \
	"${CAKER_APP}/PlugIns" \
	"${CAKER_APP}/Library" \
	"${CAKER_APP}/Library/LaunchAgents" \
	\
	"${CAKED_APP}/Resources" \
	"${CAKED_APP}/MacOS" \
	\
	"${CAKECTL_APP}/Resources" \
	"${CAKECTL_APP}/MacOS"

xcrun xcstringstool compile \
        --output-directory "${CAKER_APP}/Resources" "${PROJECT_ROOT}/Resources/Localizable.xcstrings"

xcrun xcstringstool compile \
        --output-directory "${CAKED_APP}/Resources" "${PROJECT_ROOT}/Resources/Localizable.xcstrings"

xcrun xcstringstool compile \
        --output-directory "${CAKECTL_APP}/Resources" "${PROJECT_ROOT}/Resources/Localizable.xcstrings"

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

if [ $APPSTORE -eq 0 ]; then
	SPARKLE_FRAMEWORK="${CAKER_APP}/Frameworks/Sparkle.framework"

	cp -R "${BUILDDIR}/Sparkle.framework" "${CAKER_APP}/Frameworks/"

	for FILE in Headers PrivateHeaders Modules Versions/Current/XPCServices/Downloader.xpc; do
		FILE="${SPARKLE_FRAMEWORK}/${FILE}"
		
		if [ -d "${FILE}" ]; then
			rm -rf "${FILE}"
		fi
	done
fi

cp "${PROJECT_ROOT}/webui/webui.zip" "${CAKED_APP}/Resources/webui.zip"

if [ $USE_SMAPPSERVICE -eq 1 ]; then
	cp "${PROJECT_ROOT}/Caker/Caker/AppStore/com.aldunelabs.caker.plist" "${CAKER_APP}/Library/LaunchAgents/com.aldunelabs.caker.plist"
fi

cp -c "${BINARYDIR}/Caker" "${CAKER_APP}/MacOS/Caker"
cp -c "${BINARYDIR}/cakectl" "${CAKECTL_APP}/MacOS/cakectl"
cp -c "${BINARYDIR}/caked" "${CAKED_APP}/MacOS/caked"

cp -c "${RESOURCESDIR}/Document.icns" "${CAKER_APP}/Resources/Document.icns"
cp -c "${RESOURCESDIR}/MenuBarIcon.png" "${CAKER_APP}/Resources/MenuBarIcon.png"

cp -c "${ASSETS}/AppIcon.icns" "${CAKER_APP}/Resources/AppIcon.icns"
cp -c "${ASSETS}/Assets.car" "${CAKER_APP}/Resources/Assets.car"

cp -c "${PROJECT_ROOT}/Resources/Prompt.png" "${CAKER_APP}/Resources/Prompt.png"
cp -c "${PROJECT_ROOT}/Resources/Icons/"*.png "${CAKER_APP}/Resources/Icons"
cp -c "${PROJECT_ROOT}/Resources/Info.plist" "${CAKER_APP}/Info.plist"

cp -c "${PROJECT_ROOT}/Resources/VM.icns" "${CAKED_APP}/Resources/VM.icns"
cp -c "${PROJECT_ROOT}/Resources/VM.png" "${CAKED_APP}/Resources/VM.png"
cp -c "${PROJECT_ROOT}/Resources/caked.plist" "${CAKED_APP}/Info.plist"

cp -c "${PROJECT_ROOT}/Resources/VM.icns" "${CAKECTL_APP}/Resources/VM.icns"
cp -c "${PROJECT_ROOT}/Resources/VM.png" "${CAKECTL_APP}/Resources/VM.png"
cp -c "${PROJECT_ROOT}/Resources/cakectl.plist" "${CAKECTL_APP}/Info.plist"

if [ $APPSTORE -eq 0 ]; then
	cp -c "${PROJECT_ROOT}/Resources/caker.provisionprofile" "${CAKER_APP}/embedded.provisionprofile"
	cp -c "${PROJECT_ROOT}/Resources/caked.provisionprofile" "${CAKED_APP}/embedded.provisionprofile"
	cp -c "${PROJECT_ROOT}/Resources/cakectl.provisionprofile" "${CAKECTL_APP}/embedded.provisionprofile"
else
	cp -c "${PROJECT_ROOT}/Caker/Caker/AppStore/release/caker.provisionprofile" "${CAKER_APP}/embedded.provisionprofile"
	cp -c "${PROJECT_ROOT}/Caker/Caker/AppStore/release/caked.provisionprofile" "${CAKED_APP}/embedded.provisionprofile"
	cp -c "${PROJECT_ROOT}/Caker/Caker/AppStore/release/cakectl.provisionprofile" "${CAKECTL_APP}/embedded.provisionprofile"
fi

if [ $APPSTORE -eq 0 ] && [ -n "${SPARKLE_PUBLIC_KEY}" ]; then
	if [[ "${BUILDRELEASE}" != "true" ]]; then
		APPCAST_URL="https://caker.aldunelabs.com/appcast/appcast-prerelease.xml"
	else
		APPCAST_URL="https://caker.aldunelabs.com/appcast/appcast.xml"
	fi

	plutil -replace SUFeedURL -string "${APPCAST_URL}" "${CAKER_APP}/Info.plist"
	plutil -replace SUPublicEDKey -string "${SPARKLE_PUBLIC_KEY}" "${CAKER_APP}/Info.plist"
elif [ $APPSTORE -eq 1 ]; then
	plutil -remove SUFeedURL "${CAKER_APP}/Info.plist" 2>/dev/null || true
	plutil -remove SUPublicEDKey "${CAKER_APP}/Info.plist" 2>/dev/null || true
	plutil -remove SUAllowsAutomaticUpdates "${CAKER_APP}/Info.plist" 2>/dev/null || true
	plutil -remove SUEnableAutomaticChecks "${CAKER_APP}/Info.plist" 2>/dev/null || true
	plutil -remove SUScheduledCheckInterval "${CAKER_APP}/Info.plist" 2>/dev/null || true
fi

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CAKER_APP}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CAKER_APP}/Info.plist"

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CAKED_APP}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CAKED_APP}/Info.plist"

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${CAKECTL_APP}/Info.plist"
plutil -replace CFBundleVersion -string "${VERSION}" "${CAKECTL_APP}/Info.plist"

if [ "${APPSTORE}" -eq 1 ]; then
	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--identifier "com.aldunelabs.caker.cakectl" \
		--timestamp \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/cakectl.entitlements" \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--strip-disallowed-xattrs \
		--force "${CAKECTL_APP}/MacOS/cakectl"

	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--identifier "com.aldunelabs.caker.caked" \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/caked.entitlements" \
		--strip-disallowed-xattrs \
		--force "${CAKED_APP}/MacOS/caked"

	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/release.entitlements" \
		--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/com.aldunelabs.caker}" \
		--strip-disallowed-xattrs \
		--force "${CAKER_APP}/MacOS/Caker"

	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/caked.entitlements" \
		--strip-disallowed-xattrs \
		--force "${CAKER_APP}/PlugIns/caked.bundle"

	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/cakectl.entitlements" \
		--strip-disallowed-xattrs \
		--force "${CAKER_APP}/PlugIns/cakectl.bundle"

	codesign ${KEYCHAIN_OPTIONS} --sign "Apple Distribution: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--preserve-metadata=identifier,flags,runtime,launch-constraints,library-constraints \
		--entitlements "${PROJECT_ROOT}/Caker/Caker/AppStore/release.entitlements" \
		--strip-disallowed-xattrs \
		--force "${PKGDIR}"

elif [ "${RELEASE}" -eq 1 ] && [ -n "${DEVELOPER_ID}" ]; then
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

	codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
		--options runtime \
		--timestamp \
		--preserve-metadata=identifier,entitlements,flags \
		--force "${CAKECTL_APP}/MacOS/cakectl"

	if [ -n "${CODESIGN_REQUIREMENT}" ]; then
		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/caked}" \
			--force "${CAKED_APP}/MacOS/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/com.aldunelabs.caker}" \
			--force "${CAKER_APP}/MacOS/Caker"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/com.aldunelabs.caker}" \
			--force "${CAKER_APP}/PlugIns/caked.bundle"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--entitlements "${PROJECT_ROOT}/Resources/release/cakectl.entitlements" \
			--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/com.aldunelabs.caker}" \
			--force "${CAKER_APP}/PlugIns/cakectl.bundle"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--timestamp \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--requirement="${CODESIGN_REQUIREMENT/__IDENTIFIER__/com.aldunelabs.caker}" \
			--force "${PKGDIR}"
	else
		echo "Warning: CODESIGN_REQUIREMENT not set, skipping requirement check for code signing"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--force "${CAKED_APP}/MacOS/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/cakectl.entitlements" \
			--force "${CAKECTL_APP}/MacOS/cakectl"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--force "${CAKED_APP}/MacOS/caked"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--force "${CAKER_APP}/PlugIns/caked.bundle"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--preserve-metadata=identifier,entitlements,flags \
			--entitlements "${PROJECT_ROOT}/Resources/release/cakectl.entitlements" \
			--force "${CAKER_APP}/PlugIns/cakectl.bundle"

		codesign ${KEYCHAIN_OPTIONS} --sign "Developer ID Application: ${DEVELOPER_ID}" \
			--options runtime \
			--entitlements "${PROJECT_ROOT}/Resources/release/caker.entitlements" \
			--force "${PKGDIR}"
	fi
else
	echo "Build unsigned debug binaries"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/debug/cakectl.entitlements" --force "${CAKECTL_APP}/MacOS/cakectl"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/debug/caker.entitlements" --force "${CAKED_APP}/MacOS/caked"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/debug/caker.entitlements" --force "${CAKER_APP}/Frameworks/Sparkle.framework/Versions/Current"
	codesign --sign - --entitlements "${PROJECT_ROOT}/Resources/debug/caker.entitlements" --force "${CAKER_APP}/MacOS/Caker"
fi
