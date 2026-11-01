import Foundation

/// The guest-side compose DNS wiring of the **App Store build**.
///
/// The App Store build is sandboxed and never runs caked's own DHCP server (`NetworksHandler.usesCakerDHCP` is
/// always false there, see `DHCPServer`): the networks keep vmnet's DHCP and DNS proxy, which can't advertise the
/// compose resolver (bound to the gateway on `ComposeDNS.internalBindPort`, not 53). So the guests are pointed at it
/// from the inside, by the agent install scripts, exactly as before the per-network DHCP server existed. The full
/// build gets the compose domain on port 53 straight from its DHCP server and needs none of this: there the
/// fragments are empty.
enum AppStoreGuestDNS {
	/// Shell variables the fragments below read.
	private static func variables(domain: String, ip: String, port: String) -> String {
		"COMPOSEDONS_DOMAIN_SUFFIX=\"\(domain)\"\nCOMPOSEDONS_DNS_IP=\"\(ip)\"\nCOMPOSEDONS_DNS_PORT=\"\(port)\"\n"
	}

	/// For `cloudinit-install-cakeagent.sh` (cloud images).
	static func cloudInitFragment(domain: String, ip: String, port: String) -> String {
		#if APPSTORE
			return variables(domain: domain, ip: ip, port: port) + cloudInitScript
		#else
			return ""
		#endif
	}

	/// For `ssh-install-cakeagent.sh` (PackerLite/ISO guests, already inside its `if` block, hence the indentation).
	static func sshFragment(domain: String, ip: String, port: String) -> String {
		#if APPSTORE
			return variables(domain: domain, ip: ip, port: port).split(separator: "\n").map { "\t" + $0 }.joined(separator: "\n") + "\n" + sshScript
		#else
			return ""
		#endif
	}

	#if APPSTORE
		private static let cloudInitScript = #"""
if grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
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
	cat > /usr/local/sbin/compose-resolv.sh <<-EOF
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

		cat > /etc/NetworkManager/conf.d/00-compose-dns.conf <<-EOF
			[main]
			dns=dnsmasq
		EOF

		echo "server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}" > /etc/NetworkManager/dnsmasq.d/compose-dns.conf
		systemctl restart NetworkManager || :
	else
		echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
	fi

	SEARCH="${COMPOSEDONS_DOMAIN_SUFFIX}"
elif grep -qE '^ID="?(opensuse-leap|opensuse-tumbleweed|sles)"?$' /etc/os-release 2>/dev/null && command -v netconfig >/dev/null 2>&1 && systemctl is-active -q wicked; then
	# openSUSE/SLES with wicked (NetworkManager is not running): netconfig owns /etc/resolv.conf and
	# ignores a systemd-resolved drop-in. Let netconfig run dnsmasq as its DNS forwarder, and add a rule
	# that sends only the compose domain to the compose DNS server (the other lookups keep going to the
	# servers wicked learned from DHCP).
	if command -v zypper >/dev/null 2>&1; then
		zypper --non-interactive --gpg-auto-import-keys install -y dnsmasq || :
	fi

	if command -v dnsmasq >/dev/null 2>&1; then
		mkdir -p /etc/dnsmasq.d
		echo "server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}" > /etc/dnsmasq.d/compose-dns.conf
		grep -qE '^conf-dir=.*dnsmasq\.d' /etc/dnsmasq.conf 2>/dev/null || echo 'conf-dir=/etc/dnsmasq.d,*.conf' >> /etc/dnsmasq.conf

		# The compose domain is the default search domain (the DHCP one, "guest", stays after it).
		for setting in 'NETCONFIG_DNS_FORWARDER="dnsmasq"' "NETCONFIG_DNS_STATIC_SEARCHLIST=\"${COMPOSEDONS_DOMAIN_SUFFIX}\""; do
			key=$(echo "${setting}" | cut -d= -f1)

			if grep -q "^${key}=" /etc/sysconfig/network/config 2>/dev/null; then
				sed -i "s|^${key}=.*|${setting}|" /etc/sysconfig/network/config
			else
				echo "${setting}" >> /etc/sysconfig/network/config
			fi
		done

		systemctl enable dnsmasq || :
		systemctl restart dnsmasq || :
		netconfig update -f || :
	else
		echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
	fi

	SEARCH="${COMPOSEDONS_DOMAIN_SUFFIX}"
else
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

if ! grep -q '^ID=.*alpine' /etc/os-release 2>/dev/null; then
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
"""#

		private static let sshScript = #"""
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

	elif grep -qE '^ID="?(opensuse-leap|opensuse-tumbleweed|sles)"?$' /etc/os-release 2>/dev/null && command -v netconfig >/dev/null 2>&1 && systemctl is-active -q wicked; then
		# openSUSE/SLES with wicked (NetworkManager is not running): netconfig owns /etc/resolv.conf and
		# ignores a systemd-resolved drop-in. Let netconfig run dnsmasq as its DNS forwarder, and add a rule
		# that sends only the compose domain to the compose DNS server (the other lookups keep going to the
		# servers wicked learned from DHCP).
		if [ ! -f /etc/dnsmasq.d/compose-dns.conf ]; then
			if command -v zypper >/dev/null 2>&1; then
				zypper --non-interactive --gpg-auto-import-keys install -y dnsmasq || :
			fi

			if command -v dnsmasq >/dev/null 2>&1; then
				mkdir -p /etc/dnsmasq.d
				echo "server=/${COMPOSEDONS_DOMAIN_SUFFIX}/${COMPOSEDONS_DNS_IP}#${COMPOSEDONS_DNS_PORT}" > /etc/dnsmasq.d/compose-dns.conf
				grep -qE '^conf-dir=.*dnsmasq\.d' /etc/dnsmasq.conf 2>/dev/null || echo 'conf-dir=/etc/dnsmasq.d,*.conf' >> /etc/dnsmasq.conf

				# The compose domain is the default search domain (the DHCP one, "guest", stays after it).
				for setting in 'NETCONFIG_DNS_FORWARDER="dnsmasq"' "NETCONFIG_DNS_STATIC_SEARCHLIST=\"${COMPOSEDONS_DOMAIN_SUFFIX}\""; do
					key=$(echo "${setting}" | cut -d= -f1)

					if grep -q "^${key}=" /etc/sysconfig/network/config 2>/dev/null; then
						sed -i "s|^${key}=.*|${setting}|" /etc/sysconfig/network/config
					else
						echo "${setting}" >> /etc/sysconfig/network/config
					fi
				done

				systemctl enable dnsmasq || :
				systemctl restart dnsmasq || :
				netconfig update -f || :
			else
				echo 'dnsmasq could not be installed, compose DNS is not configured' >&2
			fi
		fi

		SEARCH="${COMPOSEDONS_DOMAIN_SUFFIX}"

		# Configure systemd-resolved for compose DNS if the config file exists
	elif [ ! -f /etc/systemd/resolved.conf.d/10-compose-dns.conf ]; then
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
			CON=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null || :)

			if [ -n "$CON" ]; then
				nmcli connection modify "$CON" ipv4.ignore-auto-dns yes ipv4.dns "${COMPOSEDONS_DNS_IP}" ipv4.dns-search "$SEARCH" ipv6.ignore-auto-dns yes ipv6.dns-search "$SEARCH" || true
				nmcli device reapply "$IFACE" || true
			fi
		fi

		if systemctl is-active systemd-networkd >/dev/null 2>&1; then
			systemctl restart systemd-networkd || true
		fi
	fi
"""#
	#endif
}
