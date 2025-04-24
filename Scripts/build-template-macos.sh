#!/bin/bash
DISK_SIZE=100
MACOS_VERSION=sequoia
TART_HOME=${HOME}/.cake
CAKE_HOME=${TART_HOME}
CAKEAGENT_SNAPSHOT="SNAPSHOT-0563d90b"
REGISTRY=devregistry.aldunelabs.com
IPSW=https://updates.cdn-apple.com/2025SpringFCS/fullrestores/082-16517/AACDDC33-9683-4431-98AF-F04EF7C15EE3/UniversalMac_15.4_24E248_Restore.ipsw
RESOLVE_VM_NAME="macos-${MACOS_VERSION}-vanilla"
RESOLVE_FILE="${RESOLVE_VM_NAME}.txt"

pushd ./templates/macos

packer init templates/vanilla-${MACOS_VERSION}.pkr.hcl
packer build \
		-var cake_home=${CAKE_HOME} \
		-var cakeagent_snapshot=${CAKEAGENT_SNAPSHOT} \
		-var disk_size=${DISK_SIZE} \
		-var vm_name=${RESOLVE_VM_NAME} \
		-var resolve_file=${RESOLVE_FILE} \
		-var from_ipsw=${IPSW} \
		templates/vanilla-${MACOS_VERSION}.pkr.hcl

MACOS_NUMBER=$(cat $RESOLVE_FILE)

rm $RESOLVE_FILE

caked push ${MACOS_VERSION}-vanilla ${REGISTRY}/macos-$MACOS_VERSION-vanilla:latest ${REGISTRY}/macos-${MACOS_VERSION}-vanilla:${MACOS_NUMBER}
caked template create ${RESOLVE_VM_NAME} macos-${MACOS_VERSION}-vanilla
caked delete ${RESOLVE_VM_NAME}
popd