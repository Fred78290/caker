#!/bin/bash
#
# Take the screenshots for articles/medium-caker-app.md, one at a time, with
# Caker.app running in English.
#
# The shot list is read from the article itself: every "> 📸 **Screenshot N —
# Title.** *What to capture*" placeholder is one shot, saved as
# <output>/NN-title.png. Shots already on disk are skipped, so the script can
# be stopped and run again to continue.
#
#   Scripts/capture-article-screenshots.sh                  take the missing shots
#   Scripts/capture-article-screenshots.sh --only 8,9       retake shots 8 and 9
#   Scripts/capture-article-screenshots.sh --list           print the shot list
#   Scripts/capture-article-screenshots.sh --update-article replace each placeholder
#                                                           that has a PNG with the image
#
# Environment:
#   CAKER_APP        path to Caker.app (default: the app registered for the bundle id)
#   CAKER_BUNDLE_ID  bundle id to launch (default: com.aldunelabs.caker)
#   DELAY            seconds before a delayed full-screen capture (default: 6)
#   NO_SHADOW=1      capture windows without their drop shadow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

set -e

ARTICLE="${PROJECT_ROOT}/articles/medium-caker-app.md"
OUTPUT_DIR="${PROJECT_ROOT}/articles/images/caker-app"
BUNDLE_ID="${CAKER_BUNDLE_ID:-com.aldunelabs.caker}"
DELAY="${DELAY:-6}"
ONLY=""
FORCE=0
LAUNCH=1
MODE=capture

usage() {
	sed -n '3,/^$/s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
	echo
	cat <<EOF
Options:
  --article <file>   article to read the shots from (default: articles/medium-caker-app.md)
  --output <dir>     where to save the PNGs (default: articles/images/caker-app)
  --only <n,n,...>   take only these shots, even if they already exist
  --force            retake every shot
  --no-launch        don't relaunch Caker in English, use it as it is
  --list             print the shot list and exit
  --update-article   replace the placeholders that have a PNG, then exit
  -h, --help         show this help
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--article) ARTICLE="$2"; shift 2 ;;
	--output) OUTPUT_DIR="$2"; shift 2 ;;
	--only) ONLY=",$2,"; shift 2 ;;
	--force) FORCE=1; shift ;;
	--no-launch) LAUNCH=0; shift ;;
	--list) MODE=list; shift ;;
	--update-article) MODE=update; shift ;;
	-h | --help) usage; exit 0 ;;
	*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
	esac
done

if [ ! -f "${ARTICLE}" ]; then
	echo "Article not found: ${ARTICLE}" >&2
	exit 1
fi

# Turn "VM window, display mode" into "vm-window-display-mode".
slugify() {
	printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Read the placeholders into parallel arrays (bash 3.2 has no associative arrays).
NUMBERS=()
TITLES=()
DESCRIPTIONS=()
FILES=()

# A shot is either still a placeholder, or an "![Title](.../NN-title.png)" line
# written by --update-article, so a shot already in the article can be retaken.
PLACEHOLDER='^> [^ ]+ \*\*Screenshot [0-9]+ '
IMAGE='^!\[[^]]*\]\([^)]*/[0-9]+-[^)/]*\.png\)$'

while IFS= read -r line; do
	if printf '%s' "${line}" | LC_ALL=C grep -Eq "${PLACEHOLDER}"; then
		number=$(printf '%s' "${line}" | LC_ALL=C sed -E 's/^> [^ ]+ \*\*Screenshot ([0-9]+) .*$/\1/')
		title=$(printf '%s' "${line}" | LC_ALL=C sed -E 's/^> [^ ]+ \*\*Screenshot [0-9]+ [^ ]+ (.*)\.\*\* \*.*$/\1/')
		description=$(printf '%s' "${line}" | LC_ALL=C sed -E 's/^.*\.\*\* \*(.*)\*$/\1/')
	else
		number=$(printf '%s' "${line}" | LC_ALL=C sed -E 's/^.*\/0*([0-9]+)-[^/]*\.png\)$/\1/')
		title=$(printf '%s' "${line}" | LC_ALL=C sed -E 's/^!\[(.*)\]\(.*$/\1/')
		description="Already in the article; see the placeholder in git history for what it shows."
	fi

	NUMBERS+=("${number}")
	TITLES+=("${title}")
	DESCRIPTIONS+=("${description}")
	FILES+=("${OUTPUT_DIR}/$(printf '%02d' "${number}")-$(slugify "${title}").png")
done < <(LC_ALL=C grep -E "${PLACEHOLDER}|${IMAGE}" "${ARTICLE}")

if [ ${#NUMBERS[@]} -eq 0 ]; then
	echo "No screenshot placeholders found in ${ARTICLE}." >&2
	exit 1
fi

selected() {
	[ -z "${ONLY}" ] && return 0
	case "${ONLY}" in *",$1,"*) return 0 ;; esac
	return 1
}

if [ "${MODE}" = list ]; then
	for i in "${!NUMBERS[@]}"; do
		state="missing"
		[ -s "${FILES[$i]}" ] && state="taken"
		printf '%2s. %-45s %s\n' "${NUMBERS[$i]}" "${TITLES[$i]}" "${state}"
	done
	exit 0
fi

if [ "${MODE}" = update ]; then
	article_dir="$(cd "$(dirname "${ARTICLE}")" && pwd)"
	total=0

	for i in "${!NUMBERS[@]}"; do
		[ -s "${FILES[$i]}" ] || continue
		total=$((total + 1))
		relative=$(perl -MFile::Spec -e 'print File::Spec->abs2rel($ARGV[0], $ARGV[1])' "${FILES[$i]}" "${article_dir}")
		image="![${TITLES[$i]}](${relative})"

		perl -i -pe 'BEGIN { $n = shift; $image = shift } s/^> \S+ \*\*Screenshot \Q$n\E \S+ .*$/$image/' "${NUMBERS[$i]}" "${image}" "${ARTICLE}"
	done

	missing=$((${#NUMBERS[@]} - total))
	echo "${total} of ${#NUMBERS[@]} shots are in ${ARTICLE}; ${missing} still missing."
	exit 0
fi

if [ "$(uname -s)" != Darwin ] || ! command -v screencapture >/dev/null 2>&1; then
	echo "This script takes screenshots with macOS's screencapture: run it on the Mac where Caker is installed." >&2
	exit 1
fi

caker_running() {
	pgrep -x Caker >/dev/null 2>&1
}

# A running app ignores launch arguments, so switching Caker to English means
# quitting it first. Quitting goes through the app, so a VM running inside it
# still gets Caker's own "VM running" confirmation.
launch_in_english() {
	if caker_running; then
		echo "Caker is running. It has to be restarted to switch to English."
		read -r -p "Quit Caker and relaunch it in English? [y/N] " answer

		case "${answer}" in
		y | Y | yes | YES) ;;
		*)
			echo "Keeping the running Caker, in its current language."
			return
			;;
		esac

		osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true

		for _ in $(seq 1 60); do
			caker_running || break
			sleep 1
		done

		if caker_running; then
			echo "Caker is still running (it may be waiting for you to confirm quitting). Quit it, then run this script again." >&2
			exit 1
		fi
	fi

	if [ -n "${CAKER_APP}" ]; then
		open -a "${CAKER_APP}" --args -AppleLanguages "(en)" -AppleLocale en_US
	else
		open -b "${BUNDLE_ID}" --args -AppleLanguages "(en)" -AppleLocale en_US
	fi

	echo "Caker is starting in English."
	sleep 3
}

shadow_flag=""
[ "${NO_SHADOW}" = 1 ] && shadow_flag="-o"

# Returns 0 when a non-empty PNG was written.
capture() {
	local how="$1" file="$2"

	rm -f "${file}"

	case "${how}" in
	window)
		echo "Click the window to capture (Esc to cancel)."
		screencapture -i -W -x ${shadow_flag} "${file}" || true
		;;
	region)
		echo "Drag the area to capture (Esc to cancel)."
		screencapture -i -s -x "${file}" || true
		;;
	delayed)
		echo "Capturing the whole screen in ${DELAY} seconds: open the menu now."
		screencapture -T "${DELAY}" -x "${file}" || true
		;;
	esac

	[ -s "${file}" ]
}

mkdir -p "${OUTPUT_DIR}"

cat <<EOF
Caker screenshots for $(basename "${ARTICLE}"), saved in ${OUTPUT_DIR}

Before you start:
  - Terminal needs Screen Recording permission (System Settings > Privacy & Security >
    Screen & System Audio Recording). Without it, captures show only the wallpaper.
  - Set Caker up for each shot (VMs running, the right window open) before you press a key.

EOF

[ "${LAUNCH}" = 1 ] && launch_in_english

taken=0
skipped=0

for i in "${!NUMBERS[@]}"; do
	number="${NUMBERS[$i]}"
	file="${FILES[$i]}"

	selected "${number}" || continue

	if [ -s "${file}" ] && [ "${FORCE}" = 0 ] && [ -z "${ONLY}" ]; then
		continue
	fi

	while true; do
		echo
		echo "Screenshot ${number}/${#NUMBERS[@]}: ${TITLES[$i]}"
		echo "  ${DESCRIPTIONS[$i]}"
		echo "  -> $(basename "${file}")"
		read -r -p "  [Enter] click a window, r drag a region, d full screen in ${DELAY}s (menus), s skip, q quit: " choice

		case "${choice}" in
		"" | w) how=window ;;
		r) how=region ;;
		d) how=delayed ;;
		s)
			skipped=$((skipped + 1))
			break
			;;
		q)
			echo "Stopped. Run the script again to continue with the shots still missing."
			exit 0
			;;
		*)
			echo "  Unknown choice: ${choice}"
			continue
			;;
		esac

		if capture "${how}" "${file}"; then
			echo "  Saved $(basename "${file}")"
			taken=$((taken + 1))
			break
		fi

		echo "  Nothing was captured, try again."
	done
done

echo
echo "Done: ${taken} taken, ${skipped} skipped."
echo "Run with --list to see what is still missing, and with --update-article to put the images in the article."
echo "Caker stays in English until you quit it; the next normal launch uses your Mac's language again."
