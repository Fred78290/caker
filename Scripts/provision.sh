#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/.env"

set -e

caked delete $1 || :
caked duplicate vanilla-$1 $1
caked provision $1 --foreground --log-level=debug \
	--var "redhat_username=${REDHAT_USERNAME}" \
	--var "redhat_password=${REDHAT_PASSWORD}" \
	--template "${PROJECT_ROOT}/Sources/cakedlib/PackerLite/Resources/vanilla-$1.packerlite.yaml"
