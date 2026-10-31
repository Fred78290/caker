#!/bin/sh

COMPOSEDONS_DOMAIN_SUFFIX="%@"
COMPOSEDONS_DNS_IP="%@"
COMPOSEDONS_DNS_PORT="%@"
LISTEN_PORT="%@"
LINUX_MOUNTS="%@"
CACERT="%@"
SERVERKEY="%@"
SERVERPEM="%@"

CA_CERT_PATH=/etc/cakeagent/ssl/ca.pem
TLS_CERT_PATH=/etc/cakeagent/ssl/server.pem
TLS_KEY_PATH=/etc/cakeagent/ssl/server.key

# The Leap Minimal-VM cloud images ship no repository definition (no openSUSE-repos package), so zypper
# finds no package at all (dnsmasq for the compose DNS, semanage for the agent): add the official oss
# repository of the running release before anything is installed.
if command -v zypper >/dev/null 2>&1 && ! grep -qs '^enabled=1' /etc/zypp/repos.d/*.repo; then
	REPO=$(. /etc/os-release; if [ "$ID" = opensuse-leap ]; then echo "https://download.opensuse.org/distribution/leap/$VERSION_ID/repo/oss/"; elif [ "$ID" = opensuse-tumbleweed ]; then echo "https://download.opensuse.org/tumbleweed/repo/oss/"; fi)
	if [ -n "$REPO" ]; then
		zypper --non-interactive addrepo --refresh "$REPO" repo-oss || :
		zypper --non-interactive --gpg-auto-import-keys refresh || :
	fi
fi

if grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
	# The network may not be up yet when cloud-init runs this: retry, with a fresh index.
	for attempt in 1 2 3 4 5 6 7 8 9 10; do
		apk update && apk add dnsmasq && break
		sleep 3
	done

	mkdir -p /etc/dnsmasq.d /etc/udhcpc
	cat > /etc/dnsmasq.d/compose-dns.conf <<EOF
server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}
server=${COMPOSEDONS_DNS_IP}
server=1.1.1.1
server=9.9.9.9
server=8.8.8.8
no-resolv
listen-address=127.0.0.1
strict-order
EOF

	# udhcpc and dhcpcd (the Alpine cloud images use dhcpcd) both rewrite /etc/resolv.conf.
	echo 'RESOLV_CONF="no"' >> /etc/udhcpc/udhcpc.conf
	echo 'PEER_DNS="no"' >> /etc/udhcpc/udhcpc.conf

	if [ -f /etc/dhcpcd.conf ] || command -v dhcpcd >/dev/null 2>&1; then
		grep -q '^nohook resolv.conf' /etc/dhcpcd.conf 2>/dev/null || echo 'nohook resolv.conf' >> /etc/dhcpcd.conf
	fi

	# Those opt-outs are only read on a new lease and not every client honours them: whatever the
	# client wrote, the post-lease hooks put the compose search domain and dnsmasq back.
	mkdir -p /usr/local/sbin
	cat > /usr/local/sbin/compose-resolv.sh <<EOF
#!/bin/sh

[ -x /usr/sbin/dnsmasq ] || exit 0
cat > /etc/resolv.conf <<SHELL
search ${COMPOSEDONS_DOMAIN_SUFFIX}
nameserver 127.0.0.1
SHELL

EOF
	chmod +x /usr/local/sbin/compose-resolv.sh
	for ev in bound renew; do
		mkdir -p /etc/udhcpc/post-$ev
		ln -sf /usr/local/sbin/compose-resolv.sh /etc/udhcpc/post-$ev/10-compose-dns
	done
	grep -q compose-resolv /etc/dhcpcd.exit-hook 2>/dev/null || echo '/usr/local/sbin/compose-resolv.sh' >> /etc/dhcpcd.exit-hook
	# Only point resolv.conf at dnsmasq when it is really installed, else the guest loses DNS.
	if command -v dnsmasq >/dev/null 2>&1; then
		rc-update add dnsmasq default || :
		rc-service dnsmasq restart || :
		/usr/local/sbin/compose-resolv.sh
	else
		echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
	fi
elif grep -qE '^ID="?(centos|rhel|rocky|almalinux|ol)"?$' /etc/os-release 2>/dev/null || { grep -qE '^ID="?(opensuse-leap|opensuse-tumbleweed|sles)"?$' /etc/os-release 2>/dev/null && systemctl is-active -q NetworkManager; }; then
	# EL has no systemd-resolved by default, nor has openSUSE (Leap 16 runs NetworkManager, the Minimal-VM
	# image has no resolved to receive a drop-in): NetworkManager owns /etc/resolv.conf, so let its
	# dnsmasq plugin forward only the compose domain and leave every other lookup untouched.
	if command -v zypper >/dev/null 2>&1; then
		zypper --non-interactive --gpg-auto-import-keys install -y dnsmasq || :
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y dnsmasq || :
	else
		yum install -y dnsmasq || :
	fi

	if command -v dnsmasq >/dev/null 2>&1; then
		mkdir -p /etc/NetworkManager/conf.d /etc/NetworkManager/dnsmasq.d
		cat > /etc/NetworkManager/conf.d/00-compose-dns.conf <<'EOF'
[main]
dns=dnsmasq
EOF

		echo "server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}" > /etc/NetworkManager/dnsmasq.d/compose-dns.conf
		systemctl restart NetworkManager || :
	else
		echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
	fi

	SEARCH="${COMPOSEDONS_DOMAIN_SUFFIX}"
else
	# With systemd-resolved a link's search domain also routes its lookups to that link's DNS
	# (the gateway, port 53): keep it off the link so the global DNS=<ip>:<port> serves the domain.
	SEARCH=""
	mkdir -p /etc/systemd/resolved.conf.d
	cat > /etc/systemd/resolved.conf.d/10-compose-dns.conf <<EOF
[Resolve]
DNS=${COMPOSEDONS_DNS_IP}:${COMPOSEDONS_DNS_PORT}
Domains=${COMPOSEDONS_DOMAIN_SUFFIX}
EOF

	if command -v systemctl >/dev/null 2>&1; then
		systemctl enable systemd-resolved || :
		systemctl restart systemd-resolved || :
	fi
fi

if ! grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
	D="${COMPOSEDONS_DOMAIN_SUFFIX}"
	G="${COMPOSEDONS_DNS_IP}"

	# vmnet's DHCP server announces the domain "guest": keep it out of the search list so the
	# default domain is the compose one, whichever network stack the guest uses.
	mkdir -p /etc/systemd/networkd.conf.d
	cat > /etc/systemd/networkd.conf.d/10-compose-dns.conf <<'EOF'
[DHCPv4]
UseDomains=no
[DHCPv6]
UseDomains=no
EOF

	if [ -f /etc/dhcp/dhclient.conf ] && ! grep -q 'compose-dns' /etc/dhcp/dhclient.conf; then
		cat > /etc/dhcp/dhclient.conf <<EOF
# compose-dns
supersede domain-name "${COMPOSEDONS_DOMAIN_SUFFIX}";
supersede domain-search "${COMPOSEDONS_DOMAIN_SUFFIX}";
EOF
	fi

	if command -v nmcli >/dev/null 2>&1 && systemctl is-active NetworkManager >/dev/null 2>&1; then
		IFACE=$(ip route get "$G" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
		CON=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null)

		if [ -n "$CON" ]; then
			nmcli connection modify "$CON" ipv4.ignore-auto-dns yes ipv4.dns "$G" ipv4.dns-search "$SEARCH" ipv6.ignore-auto-dns yes ipv6.dns-search "$SEARCH" || true
			nmcli device reapply "$IFACE" || true
		fi
	fi

	if systemctl is-active systemd-networkd >/dev/null 2>&1; then
		systemctl restart systemd-networkd || true
	fi
fi

# SELinux is turned off on every image that has it: permissive right now (setenforce), disabled from
# the next boot (the config file; the running kernel keeps SELinux until then).
if [ -f /etc/selinux/config ]; then
	if grep -q '^SELINUX=' /etc/selinux/config; then
		sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	else
		echo 'SELINUX=disabled' >> /etc/selinux/config
	fi

	if command -v setenforce >/dev/null 2>&1; then
		setenforce 0 || :
	elif [ -w /sys/fs/selinux/enforce ]; then
		echo -n 0 > /sys/fs/selinux/enforce
	fi
fi

# The agent labels itself with semanage/restorecon whenever the image has an SELinux policy,
# whatever its mode (CentOS/RHEL are switched to disabled above, the agent still needs semanage),
# and a minimal cloud image does not always ship it: install it before the agent does its setup.
# The package name differs between distros and releases, so fall back to the file it provides.
if [ -f /etc/selinux/config ] && ! command -v semanage >/dev/null 2>&1; then
	for attempt in 1 2 3 4 5; do
		if command -v zypper >/dev/null 2>&1; then
			zypper --non-interactive --gpg-auto-import-keys install -y policycoreutils-python-utils || zypper --non-interactive --gpg-auto-import-keys install -y /usr/sbin/semanage
		elif command -v dnf >/dev/null 2>&1; then
			dnf install -y policycoreutils-python-utils || dnf install -y /usr/sbin/semanage || dnf install -y /usr/bin/semanage
		elif command -v yum >/dev/null 2>&1; then
			yum install -y policycoreutils-python-utils || yum install -y /usr/sbin/semanage
		else
			break
		fi

		command -v semanage >/dev/null 2>&1 && break
		sleep 5
	done
	command -v semanage >/dev/null 2>&1 || echo 'semanage could not be installed, the agent cannot label itself for SELinux' >&2
fi

# On openSUSE, Write file to /etc/cakeagent/ssl/server.key fails if the parent directory does not exist.
if [ -n "${CACERT}" ] && [ -n "${SERVERKEY}" ] && [ -n "${SERVERPEM}" ] && [ ! -f /etc/cakeagent/ssl/server.key ]; then
	mkdir -p /etc/cakeagent/ssl

	echo "${CACERT}" | base64 -d | gzip -d > /etc/cakeagent/ssl/ca.pem
	echo "${SERVERKEY}" | base64 -d | gzip -d > /etc/cakeagent/ssl/server.key
	echo "${SERVERPEM}" | base64 -d | gzip -d > /etc/cakeagent/ssl/server.pem
	chmod 0600 /etc/cakeagent/ssl/ca.pem
	chmod 0600 /etc/cakeagent/ssl/server.key
	chmod 0644 /etc/cakeagent/ssl/server.pem
fi

CIDATA=$(blkid -L CIDATA || :)

if [ -n "$CIDATA" ]; then
	MOUNT=$(mktemp -d)
	mount -L CIDATA $MOUNT || exit 1
	cp $MOUNT/cakeagent /usr/local/bin/cakeagent
	umount $MOUNT
	mkdir -p /etc/sysconfig
	echo "EXTRA_FLAGS=" > /etc/sysconfig/cakeagent
	chmod 644 /etc/sysconfig/cakeagent
	chmod +x /usr/local/bin/cakeagent
	/usr/local/bin/cakeagent service install --listen=vsock://any:${LISTEN_PORT} --ca-cert=${CA_CERT_PATH} --tls-cert=${TLS_CERT_PATH} --tls-key=${TLS_KEY_PATH} ${LINUX_MOUNTS}
else
	echo "CIDATA not found"
	exit 1
fi

${CA_CERT_PATH} ${TLS_CERT_PATH} ${TLS_KEY_PATH} ${LINUX_MOUNTS}
