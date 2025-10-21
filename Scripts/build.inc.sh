codesign --sign - --entitlements Resources/dev.entitlements --force ${BUILDDIR}/caker
codesign --sign - --entitlements Resources/dev.entitlements --force ${BUILDDIR}/caked
codesign --sign - --entitlements Resources/dev.entitlements --force ${BUILDDIR}/cakectl

rm -Rf ${PKGDIR}
mkdir -p ${ASSETS} ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources ${PKGDIR}/Contents/Resources/Icons

actool ${RESOURCESDIR}/Assets.xcassets \
	--compile ${ASSETS} \
	--output-format human-readable-text \
	--notices --warnings \
	--export-dependency-info ${ASSETS}/assetcatalog_dependencies_thinned \
	--output-partial-info-plist ${ASSETS}/assetcatalog_generated_info.plist_thinned \
	--app-icon AppIcon \
	--include-all-app-icons \
	--accent-color AccentColor \
	--enable-on-demand-resources NO \
	--development-region en \
	--target-device mac \
	--minimum-deployment-target 15.0 \
	--platform macosx

cp -c ${BUILDDIR}/caker ${PKGDIR}/Contents/MacOS/caker
cp -c ${BUILDDIR}/caked ${PKGDIR}/Contents/MacOS/caked
cp -c ${BUILDDIR}/cakectl ${PKGDIR}/Contents/MacOS/cakectl
cp -c ${RESOURCESDIR}/Document.icns ${PKGDIR}/Contents/Resources/Document.icns
cp -c ${RESOURCESDIR}/MenuBarIcon.png ${PKGDIR}/Contents/Resources/MenuBarIcon.png
cp -c ${ASSETS}/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c ${ASSETS}/Assets.car ${PKGDIR}/Contents/Resources/Assets.car
cp -c ${CURDIR}/Resources/Icons/*.png ${PKGDIR}/Contents/Resources/Icons
cp -c ${CURDIR}/Resources/Caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c ${CURDIR}/Resources/caked.plist ${PKGDIR}/Contents/Info.plist

mkdir -p .bin

cat > .bin/caked <<EOF
#!/bin/sh
exec "${PKGDIR}/Contents/MacOS/caked" "\$@"
EOF
chmod +x .bin/caked

rm -f .bin/cakectl
ln -s ${PKGDIR}/Contents/Resources/cakectl .bin/cakectl
