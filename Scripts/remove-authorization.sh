#!/bin/sh

sudo launchctl bootout system/com.aldunelabs.caker.authorization

sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.start-network"
sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.set-dhcp-lease"
sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.imds-redirect"
sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.import-virtual-machine"
sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.run-network"
sudo security -q authorizationdb remove "com.aldunelabs.caker.authorization.install-priviliged-files"
sudo rm -f /etc/paths.d/com.aldunelabs.caker
sudo rm -f /etc/sudoers.d/caked-pinned-${UID}