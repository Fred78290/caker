#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

set -e

caked delete $1 || :
caked duplicate vanilla-$1 $1
caked provision $1 --foreground --log-level=debug --template "${PROJECT_ROOT}/Sources/cakedlib/PackerLite/Resources/vanilla-$1.packerlite.yaml"
