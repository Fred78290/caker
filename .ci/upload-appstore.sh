#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PKG_PATH="${PKG_PATH:-${PROJECT_ROOT}/appstore/Caker.pkg}"

if [ ! -f "${PKG_PATH}" ]; then
	echo "Error: package not found at ${PKG_PATH}"
	exit 1
fi

echo "Uploading ${PKG_PATH} to App Store Connect (version ${VERSION:-unknown})..."

if [ -n "${APP_STORE_CONNECT_API_KEY_ID}" ] && [ -n "${APP_STORE_CONNECT_API_KEY_ISSUER_ID}" ]; then
	# Preferred: App Store Connect API key authentication
	xcrun altool --upload-app \
		--file "${PKG_PATH}" \
		--type macos \
		--apiKey "${APP_STORE_CONNECT_API_KEY_ID}" \
		--apiIssuer "${APP_STORE_CONNECT_API_KEY_ISSUER_ID}" \
		--verbose
elif [ -n "${APPLE_ID}" ] && [ -n "${APP_PASSWORD}" ]; then
	# Fallback: Apple ID with app-specific password
	xcrun altool --upload-app \
		--file "${PKG_PATH}" \
		--type macos \
		--username "${APPLE_ID}" \
		--password "${APP_PASSWORD}" \
		--verbose
else
	echo "Error: no App Store Connect credentials found."
	echo "Set APP_STORE_CONNECT_API_KEY_ID + APP_STORE_CONNECT_API_KEY_ISSUER_ID (recommended)"
	echo "or APPLE_ID + APP_PASSWORD (fallback)."
	exit 1
fi

echo "Upload to App Store Connect completed successfully."
