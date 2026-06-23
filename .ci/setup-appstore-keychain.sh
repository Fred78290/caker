#!/bin/bash
set -e

CERTIFICATE_PATH="${RUNNER_TEMP}/appstore_certificate.p12"
KEYCHAIN_PATH="${1:-${RUNNER_TEMP}/app-signing.keychain-db}"

echo -n "${BUILD_APPSTORE_CERTIFICATE_BASE64}" | base64 --decode > "${CERTIFICATE_PATH}"

if [ -f "${KEYCHAIN_PATH}" ]; then
	rm -f "${KEYCHAIN_PATH}"
fi

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

security import "${CERTIFICATE_PATH}" -P "${P12_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
security set-key-partition-list -S apple-tool:,apple: -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security list-keychain -d user -s "${KEYCHAIN_PATH}"

rm -f "${CERTIFICATE_PATH}"
echo "App Store keychain configured at ${KEYCHAIN_PATH}"
