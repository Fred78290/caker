#!/bin/bash

# helper script to build webui
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

pushd ${PROJECT_ROOT}/webui > /dev/null

npm install
npm ci --no-audit --no-fund
npm run build

pushd dist > /dev/null
zip -r ../webui.zip .
popd > /dev/null

cp "${PROJECT_ROOT}/webui/webui.zip" "${PROJECT_ROOT}/dist/Caker.app/Contents/PlugIns/caked.bundle/Contents/Resources/webui.zip"

popd > /dev/null

