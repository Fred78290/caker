#!/bin/bash
set -e

# create variables
mkdir -p "${RUNNER_TEMP}/certs"
APPLE_DEVELOPMENT_CERT_PATH="${RUNNER_TEMP}/certs/apple_development_certificate.p12"
APPLE_DISTRIBUTION_CERT_PATH="${RUNNER_TEMP}/certs/apple_distribution_certificate.p12"
DEVELOPER_ID_APPLICATION_CERT_PATH="${RUNNER_TEMP}/certs/developer_id_application_certificate.p12"
DEVELOPER_ID_INSTALLER_CERT_PATH="${RUNNER_TEMP}/certs/developer_id_installer_certificate.p12"
MAC_INSTALLER_CERT_PATH="${RUNNER_TEMP}/certs/mac_installer_certificate.p12"
MAC_DEVELOPER_CERT_PATH="${RUNNER_TEMP}/certs/mac_developer_certificate.p12"

KEYCHAIN_PATH="${RUNNER_TEMP}/app-signing.keychain-db"

# import certificate and provisioning profile from secrets
echo -n "${APPLE_DEVELOPMENT_CERT}" | base64 --decode > "${APPLE_DEVELOPMENT_CERT_PATH}"
echo -n "${APPLE_DISTRIBUTION_CERT}" | base64 --decode > "${APPLE_DISTRIBUTION_CERT_PATH}"
echo -n "${DEVELOPER_ID_APPLICATION_CERT}" | base64 --decode > "${DEVELOPER_ID_APPLICATION_CERT_PATH}"
echo -n "${DEVELOPER_ID_INSTALLER_CERT}" | base64 --decode > "${DEVELOPER_ID_INSTALLER_CERT_PATH}"
echo -n "${MAC_INSTALLER_CERT}" | base64 --decode > "${MAC_INSTALLER_CERT_PATH}"
echo -n "${MAC_DEVELOPER_CERT}" | base64 --decode > "${MAC_DEVELOPER_CERT_PATH}"

touch "${KEYCHAIN_PATH}"

# Checking if we can write to the keychain path
if [ -f "${KEYCHAIN_PATH}" ]; then
	echo "Keychain created at ${KEYCHAIN_PATH}"
	rm -f "${KEYCHAIN_PATH}"
	security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
	security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
	security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

	# import certificate to keychain
	security import "${APPLE_DEVELOPMENT_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security import "${APPLE_DISTRIBUTION_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security import "${DEVELOPER_ID_APPLICATION_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security import "${DEVELOPER_ID_INSTALLER_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security import "${MAC_INSTALLER_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security import "${MAC_DEVELOPER_CERT_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
	security set-key-partition-list -S apple-tool:,apple: -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

	# Append to the search list instead of replacing it, otherwise login.keychain-db
	# is silently dropped from the search list (list-keychains -s overwrites, not appends).
	EXISTING_KEYCHAINS=$(security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')
	security list-keychains -d user -s "${KEYCHAIN_PATH}" ${EXISTING_KEYCHAINS}
else
	echo "Error: Failed to create keychain at ${KEYCHAIN_PATH}"
	exit 1
fi
# create temporary keychain
