#!/bin/bash
swift build

codesign --sign - --entitlements Resources/dev.entitlements --force .build/debug/caked

PKGDIR=./dist/Caker.app

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/caked ${PKGDIR}/Contents/MacOS/caked
cp -c Resources/caker.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/caked.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png
cp -c Resources/CakedAppIcon.png ${PKGDIR}/Contents/Resources/AppIcon.png

BIN_PATH=$(swift build --show-bin-path)
BIN_PATH=${PKGDIR}/Contents/MacOS

SHARED_NET_ADDRESS=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address)
DISK_SIZE=20
CLOUD_IMAGE=https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
#LXD_IMAGE=images:ubuntu/noble/cloud
LXD_IMAGE=ubuntu:noble
#LXD_IMAGE=images:fedora/41/cloud
OCI_IMAGE=devregistry.aldunelabs.com/ubuntu:latest
DESKTOP=NO
#CMD="cakectl --insecure "
CMD="caked "
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
      dhcp4: true
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
#timezone: Europe/Paris
#growpart:
#  mode: auto
#  devices: ["/"]
#  ignore_growroot_disabled: false
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
users:
- name: local
  plain_text_passwd: admin
  lock_passwd: false
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups: users, admin
  shell: /bin/bash
  ssh_authorized_keys:
  - ssh-rsa ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDhniyEBZs0t7aQZhn8gWfYrFacYJKQQx9x6pckZvMJIceLsQPB/J9CbqARtcCKZkK47yDzlH/zZNwt/AJvOawKZp6LDIWMOMF6TGicVhA+0RD3dOuqKRT0uJmaSo3Cz0GAaanTJXkhsEDZzaPkyLWXYaf6LxGAuMKCxv69j4H9ffGhRxNZ+62bs7DY+SH12hlcObZaz9GRydvEI/PUDghKJ4h1QKgvCKM1Mre1vQ2DHOuSifQC0Qbh0zK/JiJpHyBgFWRvKz72e2ya6+RW0ZuDGa6Qc3Zt8FIfH6eoiX+WOG7BUsXRN3n5gcWSXyYA9kxzBlNdMyYtD0fRlyb3+HgL
EOF

if [ ${DESKTOP} != NO ]; then
cat >> /tmp/user-data.yaml <<EOF
packages:
- ubuntu-desktop-minimal
- xrdp
- spice-vdagent
EOF
fi

BUILD_OPTIONS="--user admin --password admin --clear-password --name linux --display-refit --publish 2222:22/tcp --cpu=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --mount=~/Projects --mount=~/Downloads --network=nat --user-data=/tmp/user-data.yaml"
#BUILD_OPTIONS="--user admin --password admin --clear-password --name linux --display-refit --cpu=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --mount=~ --network=nat --user-data=/tmp/user-data.yaml"
#BUILD_OPTIONS="--user admin --password admin --clear-password --name linux --display-refit --publish 2222:22/tcp --cpu=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --network-config=/tmp/network-config.yaml --user-data=/tmp/user-data.yaml"

${BIN_PATH}/${CMD} delete linux
#${BIN_PATH}/${CMD} build ${BUILD_OPTIONS} ${CLOUD_IMAGE} 
${BIN_PATH}/${CMD} build ${BUILD_OPTIONS} ${LXD_IMAGE}
#${BIN_PATH}/${CMD} launch linux ${BUILD_OPTIONS} ${OCI_IMAGE}
#${BIN_PATH}/${CMD} waitip linux --wait 60