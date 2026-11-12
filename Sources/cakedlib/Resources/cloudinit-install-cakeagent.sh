#!/bin/sh

LISTEN_PORT="%@"
LINUX_MOUNTS="%@"
CACERT="%@"
SERVERKEY="%@"
SERVERPEM="%@"

CA_CERT_PATH=/etc/cakeagent/ssl/ca.pem
TLS_CERT_PATH=/etc/cakeagent/ssl/server.pem
TLS_KEY_PATH=/etc/cakeagent/ssl/server.key

# The Leap Minimal-VM cloud images ship no repository definition (no openSUSE-repos package), so zypper
# finds no package at all (semanage for the agent): add the official oss
# repository of the running release before anything is installed.
if command -v zypper >/dev/null 2>&1 && ! grep -qs '^enabled=1' /etc/zypp/repos.d/*.repo; then
	REPO=$(. /etc/os-release; if [ "$ID" = opensuse-leap ]; then echo "https://download.opensuse.org/distribution/leap/$VERSION_ID/repo/oss/"; elif [ "$ID" = opensuse-tumbleweed ]; then echo "https://download.opensuse.org/tumbleweed/repo/oss/"; fi)
	if [ -n "$REPO" ]; then
		zypper --non-interactive addrepo --refresh "$REPO" repo-oss || :
		zypper --non-interactive --gpg-auto-import-keys refresh || :
	fi
fi

%@
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

	echo 'NOTICE: SELinux is disabled on this guest (permissive now, disabled from the next boot): caker turns it off on every distro, cloud image or ISO.'

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
