#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OCI_IMAGE=ocis://ghcr.io/cirruslabs/ubuntu:latest
DISK_SIZE=20
CMD="caked"
BUILD_OPTIONS="--display-refit --cpu=4 --memory=4096 --disk-size=${DISK_SIZE} --nested --mount=~ --network=nat"

"${CMD}" delete ubuntu
"${CMD}" build ubuntu ${BUILD_OPTIONS} ${OCI_IMAGE}
