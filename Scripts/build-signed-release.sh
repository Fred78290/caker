#!/bin/sh

# helper script to build and run a signed caked binary
# usage: ./scripts/run-signed.sh run sonoma-base
set -e

pushd $(dirname $0) >/dev/null
CURDIR=${PWD}
PKGDIR=${PWD}/../dist/Caker.app
popd > /dev/null

swift build -c release --arch x86_64
swift build -c release --arch arm64

codesign --sign - --entitlements Resources/dev.entitlements --force .build/release/caked

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/release/caked ${PKGDIR}/Contents/MacOS/caked
cp -c Resources/Caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png
cp -c Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png

mkdir .bin

cat > .bin/caked <<EOF
#!/bin/sh
exec "${PKGDIR}/Contents/MacOS/caked" "$@"
EOF

chmod +x .bin/caked
