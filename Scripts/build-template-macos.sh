#!/bin/bash
set -e

pushd "$(dirname $0)/.." >/dev/null
CURDIR=${PWD}
popd > /dev/null

export DISK_SIZE=100
export MACOS_VERSION=sequoia
export TART_HOME=${HOME}/.cake
export CAKE_HOME=${TART_HOME}
export CAKEAGENT_SNAPSHOT="SNAPSHOT-2ed87617"
export REGISTRY=devregistry.aldunelabs.com
#IPSW=https://updates.cdn-apple.com/2025SpringFCS/fullrestores/082-16517/AACDDC33-9683-4431-98AF-F04EF7C15EE3/UniversalMac_15.4_24E248_Restore.ipsw
export IPSW=${HOME}/Downloads/UniversalMac_15.4.1_24E263_Restore.ipsw
export RESOLVE_VM_NAME="macos-${MACOS_VERSION}-vanilla"
export RESOLVE_FILE="${RESOLVE_VM_NAME}.txt"
export PACKER_LOG="1"

SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

packer init ${CURDIR}/templates/macos/vanilla-${MACOS_VERSION}.pkr.hcl
packer build \
		-var vm_name=${RESOLVE_VM_NAME} \
		-var from_ipsw=${IPSW} \
		-var disk_size=${DISK_SIZE} \
		${CURDIR}/templates/macos/vanilla-${MACOS_VERSION}.pkr.hcl

mkdir -p ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}

caked exec ${RESOLVE_VM_NAME} -- bash <<EOF
set -ex
mkdir -p /etc/sudoers.d /usr/local/bin /etc/cakeagent/ssl
echo 'admin ALL=(ALL) NOPASSWD: ALL' | EDITOR=tee visudo /etc/sudoers.d/admin-nopasswd
EOF

cat > ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}/configure.sh <<EOF
#!/bin/bash
set -ex

echo '00000000: 1ced 3f4a bcbc ba2c caca 4e82' | sudo xxd -r - /etc/kcpassword
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser admin
# Disable screensaver at login screen
sudo defaults write /Library/Preferences/com.apple.screensaver loginWindowIdleTime 0
# Disable screensaver for admin user
defaults -currentHost write com.apple.screensaver idleTime 0
# Prevent the VM from sleeping
sudo systemsetup -setsleep Off 2>/dev/null
# Launch Safari to populate the defaults
/Applications/Safari.app/Contents/MacOS/Safari &
SAFARI_PID=\$!
disown
sleep 30
kill -9 \$SAFARI_PID
# Enable Safari's remote automation
sudo safaridriver --enable
# Disable screen lock
#
# Note that this only works if the user is logged-in,
# i.e. not on login screen.
sysadminctl -screenLock off -password admin

spctl --status | grep -q 'assessments disabled'
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
softwareupdate --list | sed -n 's/.*Label: \\(Command Line Tools for Xcode-.*\\)/\\1/p' | xargs -I {} softwareupdate --install '{}'
rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
sw_vers -productVersion > /tmp/sw-vers-product-version.txt
EOF

chmod +x ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}/configure.sh

sshpass -p admin scp ${SSH_OPTIONS} ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}/configure.sh admin@${IP}:/tmp/configure.sh
sshpass -p admin ssh ${SSH_OPTIONS} admin@${IP} -- /tmp/configure.sh

set -x

caked exec ${RESOLVE_VM_NAME} -- cat /tmp/sw-vers-product-version.txt > ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}/sw-vers-product-version.txt

MACOS_NUMBER=$(cat ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}/sw-vers-product-version.txt)

caked stop ${RESOLVE_VM_NAME}
caked template create ${RESOLVE_VM_NAME} macos-${MACOS_VERSION}-vanilla
caked push ${RESOLVE_VM_NAME} ${REGISTRY}/macos-$MACOS_VERSION-vanilla:latest ${REGISTRY}/macos-${MACOS_VERSION}-vanilla:${MACOS_NUMBER}
caked delete ${RESOLVE_VM_NAME}

rm -rf ${CAKE_HOME}/tmp/${RESOLVE_VM_NAME}