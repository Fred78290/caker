#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

set -e

caked delete $1 || :
caked duplicate vanilla-$1 $1
caked record $1 --log-level=debug --output "${PROJECT_ROOT}/Sources/cakedlib/PackerLite/Resources/vanilla-$1.packerlite.yaml"
