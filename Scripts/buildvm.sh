#!/bin/bash
VMNAME=$1

set -e

# Help tool to inspect the disk image
# qemu-img convert -p -f raw -O vmdk ~/.cake/vms/opensuse/disk.img ~/Virtual\ Machines.localized/ubuntu-desktop.vmwarevm/linux.vmdk

pushd "$(dirname ${BASH_SOURCE[0]})/.." >/dev/null
CURDIR=${PWD}
PKGDIR=${CURDIR}/dist/Caker.app
popd > /dev/null

BUILDDIR=${CURDIR}/.build/debug
RESOURCESDIR=${CURDIR}/Caker/Caker/Content
ASSETS=${BUILDDIR}/assets

if [ -z "$VMNAME" ]; then
    VMNAME=linux
fi

/usr/bin/swift build

source ${CURDIR}/Scripts/build.inc.sh

BIN_PATH=${PKGDIR}/Contents/MacOS
SHARED_NET_ADDRESS=$(sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address)
DISK_SIZE=20
MAINGROUP=adm
NETIFNAMES=true
USER_SHELL=/bin/bash

if [ $(uname -m) == "arm64" ]; then
   ARCH1=arm64
   ARCH2=aarch64
else
  ARCH1=x86_64
  ARCH2=amd64
fi

case ${VMNAME} in
    ubuntu*)
        CLOUD_IMAGE=https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-${ARCH1}.img
        ;;
    plucky*)
        CLOUD_IMAGE=https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-${ARCH1}.img
        ;;
    centos*)
        CLOUD_IMAGE=https://cloud.centos.org/centos/10-stream/${ARCH2}/images/CentOS-Stream-GenericCloud-10-20250506.2.${ARCH2}.qcow2
        ;;
    alpine*)
        CLOUD_IMAGE=https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-${ARCH2}-uefi-cloudinit-r0.qcow2
        USER_SHELL=/bin/sh
        ;;
    opensuse*)
        CLOUD_IMAGE=https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.${ARCH2}-NoCloud.qcow2
        MAINGROUP=root
        NETIFNAMES=false
        ;;
    fedora*)
        CLOUD_IMAGE=https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/${ARCH2}/images/Fedora-Cloud-Base-Generic-42-1.1.${ARCH2}.qcow2
        ;;
    *)
        CLOUD_IMAGE=
        ;;
esac

#LXD_IMAGE=images:ubuntu/noble/cloud
LXD_IMAGE=ubuntu:noble
#LXD_IMAGE=images:fedora/41/cloud
OCI_IMAGE=devregistry.aldunelabs.com/ubuntu:latest
DESKTOP=NO
CMD="caked"
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
package_update: false
package_upgrade: false
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
- content: |
    #!/bin/sh
    SUFFIX=${RANDOM}

    if test "\$(grep ^ID= /etc/os-release | cut -d= -f 2)" = "alpine"
    then
        hostname openstack-dev-k3s-worker-\$SUFFIX
        apk add docker
        rc-update add docker default
        service docker start
    else
      if test -n "\$(command -v hostnamectl)"
      then
          hostnamectl set-hostname openstack-dev-k3s-worker-\$SUFFIX
      else
          echo "openstack-dev-k3s-worker-\$SUFFIX" > /etc/hostname
      fi

      if test -n "\$(command -v curl)"
      then
          curl -fsSL https://get.docker.com | sh -
      else
          wget https://get.docker.com -O | sh -
      fi

      if test -n "\$(command -v systemctl)"
      then
          systemctl enable docker
          systemctl start docker
      else
          service docker start
      fi
    fi

    usermod -aG docker admin
    usermod -aG docker local
  owner: root:root
  path: /tmp/setup.sh
  permissions: '0755'
users:
- name: local
  plain_text_passwd: admin
  lock_passwd: false
  sudo: ALL=(ALL) NOPASSWD:ALL
  groups: users, ${MAINGROUP}
  shell: ${USER_SHELL}
  ssh_authorized_keys:
  - ssh-rsa ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDhniyEBZs0t7aQZhn8gWfYrFacYJKQQx9x6pckZvMJIceLsQPB/J9CbqARtcCKZkK47yDzlH/zZNwt/AJvOawKZp6LDIWMOMF6TGicVhA+0RD3dOuqKRT0uJmaSo3Cz0GAaanTJXkhsEDZzaPkyLWXYaf6LxGAuMKCxv69j4H9ffGhRxNZ+62bs7DY+SH12hlcObZaz9GRydvEI/PUDghKJ4h1QKgvCKM1Mre1vQ2DHOuSifQC0Qbh0zK/JiJpHyBgFWRvKz72e2ya6+RW0ZuDGa6Qc3Zt8FIfH6eoiX+WOG7BUsXRN3n5gcWSXyYA9kxzBlNdMyYtD0fRlyb3+HgL
runcmd:
- /tmp/setup.sh
EOF

if [ ${DESKTOP} != NO ]; then
cat >> /tmp/user-data.yaml <<EOF
- systemctl disable systemd-networkd-wait-online.service
packages:
- ubuntu-desktop-minimal
- xrdp
- spice-vdagent
EOF
fi

NETWORKS_OPTIONS="--net.ifnames=${NETIFNAMES} --network=nat --network=en0 --network=shared --network=host --console=file"
NETWORKS_OPTIONS="--net.ifnames=${NETIFNAMES} --network=nat --network=en0 --console=file"
#BUILD_OPTIONS="--user admin --password admin --clear-password --display-refit --cpus=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --mount=~ --network=nat --cloud-init=/tmp/user-data.yaml"
#BUILD_OPTIONS="--user admin --password admin --clear-password --display-refit --publish 2222:22/tcp --cpus=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --network-config=/tmp/network-config.yaml --cloud-init=/tmp/user-data.yaml"

${BIN_PATH}/${CMD} delete ${VMNAME} 

if [ -z "${CLOUD_IMAGE}" ]; then
    BUILD_OPTIONS="--autostart --user admin --password admin --main-group=${MAINGROUP} --clear-password --display-refit --dynamic-port-forwarding --publish 2222:22/tcp ${NETWORKS_OPTIONS} --publish tcp:~/.docker/run/docker.sock:/var/run/docker.sock --cpus=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --mount=~/Projects --mount=~/Downloads --cloud-init=/tmp/user-data.yaml"
    ${BIN_PATH}/${CMD} build ${VMNAME} ${BUILD_OPTIONS} ${LXD_IMAGE} 
else
    BUILD_OPTIONS="--autostart --user admin --password admin --main-group=${MAINGROUP} --clear-password --display-refit ${NETWORKS_OPTIONS} --cpus=2 --memory=2048 --disk-size=${DISK_SIZE} --nested --ssh-authorized-key=$HOME/.ssh/id_rsa.pub --mount=~/Projects --mount=~/Downloads --cloud-init=/tmp/user-data.yaml"
    ${BIN_PATH}/${CMD} build ${VMNAME} ${BUILD_OPTIONS} ${CLOUD_IMAGE} 
fi

#${BIN_PATH}/${CMD} launch ${VMNAME}  ${BUILD_OPTIONS} ${OCI_IMAGE}
#${BIN_PATH}/${CMD} waitip ${VMNAME}  --wait 60