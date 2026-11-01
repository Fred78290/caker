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
	# finds no package at all (semanage for the agent): add the official oss
	# repository of the running release before anything is installed.
	if command -v zypper >/dev/null 2>&1 && ! grep -qs '^enabled=1' /etc/zypp/repos.d/*.repo; then
		REPO=$(. /etc/os-release; if [ "$ID" = opensuse-leap ]; then echo "https://download.opensuse.org/distribution/leap/$VERSION_ID/repo/oss/"; elif [ "$ID" = opensuse-tumbleweed ]; then echo "https://download.opensuse.org/tumbleweed/repo/oss/"; fi)
		if [ -n "$REPO" ]; then
			zypper --non-interactive addrepo --refresh "$REPO" repo-oss || :
			zypper --non-interactive --gpg-auto-import-keys refresh || :
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
					zypper --non-interactive --gpg-auto-import-keys install -y policycoreutils-python-utils || zypper --non-interactive --gpg-auto-import-keys install -y /usr/sbin/semanage || :
				elif command -v dnf >/dev/null 2>&1; then
					dnf install -y policycoreutils-python-utils || dnf install -y /usr/sbin/semanage || dnf install -y /usr/bin/semanage || :
				elif command -v yum >/dev/null 2>&1; then
					yum install -y policycoreutils-python-utils || yum install -y /usr/sbin/semanage || :
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
