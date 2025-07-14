#!/bin/sh

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

pushd "$(dirname $0)/.." >/dev/null
PKGDIR=${PWD}/dist/Caker.app
popd > /dev/null

swift build -c release --arch x86_64
swift build -c release --arch arm64

codesign --sign - --entitlements Resources/dev.entitlements --force .build/release/caker
codesign --sign - --entitlements Resources/dev.entitlements --force .build/release/caked
codesign --sign - --entitlements Resources/dev.entitlements --force .build/release/cakectl

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources ${PKGDIR}/Contents/Resources/Icons
cp -c .build/release/caker ${PKGDIR}/Contents/MacOS/caker
cp -c .build/release/caked ${PKGDIR}/Contents/MacOS/caked
cp -c .build/release/cakectl ${PKGDIR}/Contents/MacOS/cakectl
cp -c Resources/Caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/AppIcon.icns ${PKGDIR}/Contents/Resources/AppIcon.icns
cp -c Resources/Document.icns ${PKGDIR}/Contents/Resources/Document.icns
cp -c Resources/Icons/*.png ${PKGDIR}/Contents/Resources/Icons

mkdir .bin

cat > .bin/caked <<EOF
#!/bin/sh
exec "${PKGDIR}/Contents/MacOS/caked" "\$@"
EOF

chmod +x .bin/caked
ln -s ${PKGDIR}/Contents/Resources/cakectl .bin/cakectl