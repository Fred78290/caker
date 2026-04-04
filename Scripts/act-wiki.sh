#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

act push --workflows "${PROJECT_ROOT}/.github/workflows/publish-wiki.yaml" \
	--secret GITHUB_TOKEN="$(gh auth token)" \
	--secret-file "${PROJECT_ROOT}/.env"\
	--var-file "${PROJECT_ROOT}/.vars" \
	--platform ubuntu-latest=catthehacker/ubuntu:act-latest \
	--eventpath "${PROJECT_ROOT}/act.json" \
	--local-repository "https://github.com/Fred78290/caker@snapshot=${PROJECT_ROOT}"