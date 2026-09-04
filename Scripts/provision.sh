#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${PROJECT_ROOT}/.env"

set -e

if [ -f ${PROJECT_ROOT}/Tests/Packer/$1.packerlite.yaml ]; then
	TEMPL_ARG="--template=${PROJECT_ROOT}/Tests/Packer/$1.packerlite.yaml"
else
	TEMPL_ARG=""
fi

caked delete $1 || :
caked duplicate vanilla-$1 $1
caked provision $1 --foreground --log-level=debug "${TEMPL_ARG}"
