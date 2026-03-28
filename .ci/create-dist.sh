#!/bin/bash
# Script pour créer à la fois le package PKG et le DMG de Caker
set -e

SNAPSHOT=$(git rev-parse --short=8 HEAD)
export VERSION_TAG=${VERSION_TAG:=SNAPSHOT-$SNAPSHOT}

pushd "$(dirname ${BASH_SOURCE[0]})" >/dev/null
CI_DIR=${PWD}
popd > /dev/null
	
if [ -f ${CI_DIR}/../.env ]; then
	source ${CI_DIR}/../.env
fi

echo "Building Caker distribution packages for version ${VERSION_TAG}..."

# Vérifier que les variables d'environnement nécessaires sont définies
if [ -z "${DEVELOPER_ID}" ]; then
	echo "Warning: DEVELOPER_ID not set. Code signing will be skipped."
fi

# Construire d'abord le PKG (qui crée aussi l'application bundle)
echo "Step 1: Creating PKG installer..."
if ! "${CI_DIR}/create-pkg.sh" "$@"; then
	echo "Error: Failed to create PKG"
	exit 1
fi

# Ensuite créer le DMG
echo "Step 2: Creating DMG distribution..."
if ! "${CI_DIR}/create-dmg.sh" "$@"; then
	echo "Error: Failed to create DMG"
	exit 1
fi

echo ""
echo "Distribution packages created successfully:"
echo "  PKG: $(dirname ${CI_DIR})/Caker-${VERSION_TAG}.pkg"
echo "  DMG: $(dirname ${CI_DIR})/Caker-${VERSION_TAG}.dmg"
echo ""
echo "The PKG can be used for installation via command line or deployment tools."
echo "The DMG provides a user-friendly drag-and-drop installation experience."