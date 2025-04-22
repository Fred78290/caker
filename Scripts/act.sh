#!/bin/sh
pushd "$(dirname $0)/.." >/dev/null
CURDIR=${PWD}
popd > /dev/null

act push --workflows "${CURDIR}/.github/workflows/release.yaml" \
	--secret GITHUB_TOKEN=${GITHUB_TOKEN} \
	--secret-file ${CURDIR}/.env \
	--var-file ${CURDIR}/.vars \
	--platform self-hosted="-self-hosted" \
	--eventpath "${CURDIR}/payload.json" \
	--local-repository "https://github.com/Fred78290/tarthelper@snapshot=${CURDIR}"