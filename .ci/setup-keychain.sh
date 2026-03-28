#!/bin/bash
set -e

# create variables
CERTIFICATE_PATH="${RUNNER_TEMP}/installer_certificate.p12"
KEYCHAIN_PATH="${RUNNER_TEMP}/app-signing.keychain-db"

# import certificate and provisioning profile from secrets
echo -n "${BUILD_CERTIFICATE_BASE64}" | base64 --decode > "${CERTIFICATE_PATH}"
	
touch "${KEYCHAIN_PATH}"

# Checking if we can write to the keychain path
if [ -f "${KEYCHAIN_PATH}" ]; then
	echo "Keychain created at ${KEYCHAIN_PATH}"
	rm -f "${KEYCHAIN_PATH}"
	security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
	security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
	security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

	# import certificate to keychain
	security import "${CERTIFICATE_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security set-key-partition-list -S apple-tool:,apple: -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
	security list-keychain -d user -s "${KEYCHAIN_PATH}"
else
	echo "Error: Failed to create keychain at ${KEYCHAIN_PATH}"
	exit 1
fi
# create temporary keychain
