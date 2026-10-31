#!/bin/sh
# Installed over SSH by VMLocation.installAgent. This is a String(format:) template: a literal % must be written %%.
trap 'sync; sync' EXIT
set -xe

CONFIGURED_USER="%1$@"
CAKEAGENT_SNAPSHOT="%2$@"
LISTEN_PORT="%3$@"
LINUX_MOUNTS="%4$@"
SSH_PUBLIC_KEYS='%5$@'
CA_CERT="%6$@"
SERVER_CERT="%7$@"
SERVER_KEY="%8$@"

case $(uname -m) in
	x86_64)
		ARCH=amd64
		;;
	aarch64|arm64)
		ARCH=arm64
		;;
esac

case $(uname -s) in
	Darwin)
		OSDISTRO=darwin
		;;
	*)
		OSDISTRO=linux
		;;
esac

if test "${OSDISTRO}" = "darwin"
then
	CERTS="/Library/Application Support/CakeAgent/certs"
	SSHDIR="/Users/${CONFIGURED_USER}/.ssh"
else
	CERTS="/etc/cakeagent/ssl"
	SSHDIR="/home/${CONFIGURED_USER}/.ssh"
fi

mkdir -p "${CERTS}"

CA="${CERTS}/ca.pem"
SERVER="${CERTS}/server.pem"
KEY="${CERTS}/server.key"
UPDATE=0

mkdir -p /usr/local/bin ${SSHDIR}

if test -f /usr/local/bin/cakeagent
then
	if test -n "$(/usr/local/bin/cakeagent version|grep "${CAKEAGENT_SNAPSHOT}")"
	then
		echo "CakeAgent already installed, skipping"
		exit 0
	else
		echo "CakeAgent already installed, updating"
		/usr/local/bin/cakeagent service stop
		UPDATE=1
	fi
fi

if test ! -f /tmp/cakeagent
then
	AGENT_URL="https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-${CAKEAGENT_SNAPSHOT}/cakeagent-${OSDISTRO}-${ARCH}"

	echo "Downloading CakeAgent from ${AGENT_URL}"

	if test -n "$(command -v curl)"; then
		curl -L "${AGENT_URL}" -o /tmp/cakeagent
	elif test -n "$(command -v wget)"
	then
		wget "${AGENT_URL}" -O /tmp/cakeagent
	else
		echo "No curl or wget found, cannot download CakeAgent"
		exit 1
	fi
fi

if test ! -f /tmp/cakeagent
then
	echo "Failed to download CakeAgent, exiting"
	exit 1
fi

echo "Install CakeAgent, setting permissions"
mv /tmp/cakeagent /usr/local/bin/cakeagent

touch ${SSHDIR}/authorized_keys

if test -z "$(grep "${SSH_PUBLIC_KEYS}" ${SSHDIR}/authorized_keys)"
then
	echo "${SSH_PUBLIC_KEYS}" >> "${SSHDIR}/authorized_keys"
	chown -R "${CONFIGURED_USER}" "${SSHDIR}"
	chmod 600 "${SSHDIR}/authorized_keys"
fi

echo "Creating CA certificate file at ${CA}"
echo ${CA_CERT} | base64 --decode > "${CA}"

echo "Creating server certificate file at ${SERVER}"
echo ${SERVER_CERT} | base64 --decode > "${SERVER}"

echo "Creating server key file at ${KEY}"
echo ${SERVER_KEY} | base64 --decode > "${KEY}"

chmod -R 600 "${CERTS}"

if test "${OSDISTRO}" = "darwin"; then
	chown root:wheel /usr/local/bin/cakeagent
	chown -R root:wheel "${CERTS}"
else
	if [ -z "$(grep 'adm:' /etc/group)" ]; then
		chown root:root /usr/local/bin/cakeagent
		chown -R root:root "${CERTS}"
	else
		chown root:adm /usr/local/bin/cakeagent
		chown -R root:adm "${CERTS}"
	fi

	mkdir -p /mnt/shared
	chmod 777 /mnt/shared

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

	# Configure dnsmasq for Alpine if not already configured
	if [ ! -f /etc/dnsmasq.d/compose-dns.conf ] && grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
		# The network may not be up yet when cloud-init runs this: retry, with a fresh index.
		for attempt in 1 2 3 4 5 6 7 8 9 10; do
			apk update && apk add dnsmasq && break
			sleep 3
		done

		mkdir -p /etc/dnsmasq.d /etc/udhcpc

		cat > /etc/dnsmasq.d/compose-dns.conf <<-EOF
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
		cat <<-EOF > /usr/local/sbin/compose-resolv.sh
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
		# Configure dnsmasq for EL and openSUSE if NetworkManager is active and the compose DNS config is not already present
		if [ ! -f /etc/NetworkManager/conf.d/00-compose-dns.conf ]; then
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
				cat > /etc/NetworkManager/conf.d/00-compose-dns.conf <<-EOF
					[main]
					dns=dnsmasq
				EOF

				echo "server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}" > /etc/NetworkManager/dnsmasq.d/compose-dns.conf
				systemctl restart NetworkManager || :
			else
				echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
			fi
		fi

		SEARCH="${COMPOSEDONS_DOMAIN_SUFFIX}"

		# Configure systemd-resolved for compose DNS if the config file exists
	elif [ -f /etc/systemd/resolved.conf.d/10-compose-dns.conf ]; then
		# With systemd-resolved a link's search domain also routes its lookups to that link's DNS
		# (the gateway, port 53): keep it off the link so the global DNS=<ip>:<port> serves the domain.
		SEARCH=""
		
		mkdir -p /etc/systemd/resolved.conf.d
		
		cat > /etc/systemd/resolved.conf.d/10-compose-dns.conf <<-EOF
			[Resolve]
			DNS=${COMPOSEDONS_DNS_IP}:${COMPOSEDONS_DNS_PORT}
			Domains=${COMPOSEDONS_DOMAIN_SUFFIX}
		EOF

		if command -v systemctl >/dev/null 2>&1; then
			systemctl enable systemd-resolved || :
			systemctl restart systemd-resolved || :
		fi
	fi

	# Configure systemd-networkd and DHCP client for compose DNS if not on Alpine and the config file doesn't exist
	if [ ! -f /etc/systemd/networkd.conf.d/10-compose-dns.conf ] && ! grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
		# vmnet's DHCP server announces the domain "guest": keep it out of the search list so the
		# default domain is the compose one, whichever network stack the guest uses.
		mkdir -p /etc/systemd/networkd.conf.d
		cat > /etc/systemd/networkd.conf.d/10-compose-dns.conf <<-EOF
			[DHCPv4]
			UseDomains=no
			[DHCPv6]
			UseDomains=no
		EOF

		if [ -f /etc/dhcp/dhclient.conf ] && ! grep -q 'compose-dns' /etc/dhcp/dhclient.conf; then
			cat > /etc/dhcp/dhclient.conf <<-EOF
				# compose-dns
				supersede domain-name "${COMPOSEDONS_DOMAIN_SUFFIX}";
				supersede domain-search "${COMPOSEDONS_DOMAIN_SUFFIX}";
			EOF
		fi

		if command -v nmcli >/dev/null 2>&1 && systemctl is-active NetworkManager >/dev/null 2>&1; then
			IFACE=$(ip route get "${COMPOSEDONS_DNS_IP}" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
			CON=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null)

			if [ -n "$CON" ]; then
				nmcli connection modify "$CON" ipv4.ignore-auto-dns yes ipv4.dns "${COMPOSEDONS_DNS_IP}" ipv4.dns-search "$SEARCH" ipv6.ignore-auto-dns yes ipv6.dns-search "$SEARCH" || true
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
		# The agent labels itself with semanage/restorecon whenever the image has an SELinux policy,
		# whatever its mode (CentOS/RHEL are switched to disabled above, the agent still needs semanage),
		# and a minimal cloud image does not always ship it: install it before the agent does its setup.
		# The package name differs between distros and releases, so fall back to the file it provides.
		if ! command -v semanage >/dev/null 2>&1; then
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

fi

chmod 755 /usr/local/bin/cakeagent

if [ $UPDATE -eq 1 ]; then
	/usr/local/bin/cakeagent service start
else
	mkdir -p /etc/sysconfig
	echo "EXTRA_FLAGS=" > /etc/sysconfig/cakeagent
	chmod 644 /etc/sysconfig/cakeagent
	/usr/local/bin/cakeagent service install \
		--listen="vsock://any:${LISTEN_PORT}" \
		--ca-cert="${CA}" \
		--tls-cert="${SERVER}" \
		--tls-key="${KEY}" ${LINUX_MOUNTS}
fi

if test "${OSDISTRO}" = "linux"; then
	mount /mnt/shared 2>/dev/null || true
fi

sync
sync
