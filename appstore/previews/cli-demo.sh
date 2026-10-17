#!/bin/bash
#
# Terminal session for the "command line" App Store preview: each command is
# typed out at a human pace, then run for real against the local caked.
#
#   CAKER_APP=/path/to/Caker.app ./cli-demo.sh [trigger-file]
#
# Open it in Terminal.app (open -a Terminal cli-demo.sh). It sizes and places
# its window, shows a prompt and waits for the trigger file to exist, so the
# recorder can be started first. cakectl needs a caked daemon listening on its
# default address (caked service listen). The VM it starts is stopped again at
# the end.

CAKER_APP="${CAKER_APP:-/Applications/Caker.app}"
TRIGGER="${1:-/tmp/caker-cli-demo.go}"
VM="${DEMO_VM:-fedora44-server}"

caked() { "${CAKER_APP}/Contents/PlugIns/caked.app/Contents/MacOS/caked" "$@"; }
cakectl() { "${CAKER_APP}/Contents/PlugIns/cakectl.app/Contents/MacOS/cakectl" "$@"; }

# Window title, position (pixels from the top-left of the screen) and size (rows; columns).
printf '\e]0;caker\a\e[3;%d;%dt\e[8;%d;%dt' "${DEMO_X:-300}" "${DEMO_Y:-180}" "${DEMO_ROWS:-34}" "${DEMO_COLS:-158}"
clear

prompt() {
	printf '\e[1;32mmac\e[0m:\e[1;34m~\e[0m$ '
}

type_out() {
	local text="$1" i

	for ((i = 0; i < ${#text}; i++)); do
		printf '%s' "${text:i:1}"
		sleep "0.0$((RANDOM % 5 + 3))"
	done

	sleep 0.5
	printf '\n'
}

run() {
	prompt
	type_out "$1"
	eval "$1"
	sleep "${2:-1.5}"
}

prompt
rm -f "${TRIGGER}"

while [ ! -e "${TRIGGER}" ]; do
	sleep 0.1
done

printf '\r'
run "caked aliases | head -11" 2.5
run "cakectl list | head -11" 3
run "clear" 0.3
# The guest agent comes up a few seconds after the IP: wait (cut in the edit).
run "cakectl start ${VM}" 8
run "cakectl exec ${VM} -- uname -sr" 2
run "cakectl infos ${VM}" 3
run "cakectl stop ${VM}" 3
prompt
sleep 600
