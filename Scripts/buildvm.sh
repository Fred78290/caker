#!/bin/bash
BIN_PATH=$(swift build --show-bin-path)

SHARED_NET_ADDRESS=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address)
DISK_SIZE=20
CLOUD_IMAGE=https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
LXD_IMAGE=ubuntu/noble/cloud
#LXD_IMAGE=centos/9-Stream/cloud
DESKTOP=NO

SHARED_NET_ADDRESS=${SHARED_NET_ADDRESS%.*}
DNS=$(scutil --dns | grep 'nameserver\[[0-9]*\]' | head -n 1 | awk '{print $ 3}')

cat > /tmp/network-config.yaml <<EOF
#cloud-config
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s1:
      match:
        name: enp0s1
      dhcp4: false
      dhcp-identifier: mac
      addresses:
      - ${SHARED_NET_ADDRESS}.10/24
      nameservers:
        addresses:
        - ${DNS}
EOF

cat > /tmp/user-data.yaml <<EOF
#cloud-config
package_update: true
package_upgrade: true
timezone: Europe/Paris
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
write_files:
- content: |
    apiVersion: kubelet.config.k8s.io/v1
    kind: CredentialProviderConfig
    providers:
      - name: ecr-credential-provider
        matchImages:
          - "*.dkr.ecr.*.amazonaws.com"
          - "*.dkr.ecr.*.amazonaws.cn"
          - "*.dkr.ecr-fips.*.amazonaws.com"
          - "*.dkr.ecr.us-iso-east-1.c2s.ic.gov"
          - "*.dkr.ecr.us-isob-east-1.sc2s.sgov.gov"
        defaultCacheDuration: "12h"
        apiVersion: credentialprovider.kubelet.k8s.io/v1
        args:
          - get-credentials
        env:
          - name: AWS_ACCESS_KEY_ID 
            value: HIDDEN
          - name: AWS_SECRET_ACCESS_KEY
            value: HIDDEN
  owner: root:root
  path: /var/lib/rancher/credentialprovider/config.yaml
  permissions: '0644'
runcmd:
- hostnamectl set-hostname openstack-dev-k3s-worker-02
EOF

if [ ${DESKTOP} != NO ]; then
cat >> /tmp/user-data.yaml <<EOF
packages:
- ubuntu-desktop-minimal
- xrdp
- spice-vdagent
EOF
fi

BUILD_OPTIONS="--cpu 2 --memory 2048 --disk-size ${DISK_SIZE} --ssh-authorized-key $HOME/.ssh/id_rsa.pub --network-config /tmp/network-config.yaml --user-data /tmp/user-data.yaml"

${BIN_PATH}/tartd delete linux
${BIN_PATH}/tartd build linux ${BUILD_OPTIONS} --cloud-image ${CLOUD_IMAGE} 
#${BIN_PATH}/tartd build linux ${BUILD_OPTIONS} --alias-image ${LXD_IMAGE}
${BIN_PATH}/tartd set --display-refit linux
${BIN_PATH}/tartd run linux --nested --disk ~/.tart/vms/linux/cloud-init.iso
