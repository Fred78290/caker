#!/bin/sh
set -e

export PATH="/usr/local/opt/bison/bin:/opt/homebrew/opt/bison/bin:/usr/bin:/usr/sbin:/bin:/Library/Apple/usr/bin:/opt/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/X11/bin:/sbin:/System/Cryptexes/App/usr/bin:/Users/fboltz/go/bin:/usr/local/bin"

usage () {
	echo "Usage: $(basename ${0}) arch1 arch2 [arch...]"
	echo ""
	echo "  archN       List of architectures to pack. [armv7|armv7s|arm64|i386|x86_64]"
	echo ""
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

pushd "$(dirname "$(realpath ${0})")/.." >/dev/null
	BASEDIR="${PWD}"
popd >/dev/null

MAIN_ARCH=$1
ALL_ARCHS=$*
DEPS=${BASEDIR}/.deps
LIBRARY="${BASEDIR}/Library"

mkdir -p "${LIBRARY}"

pack_all_objs() {
	BASEDIR="$1"
	FIND="$2"
	MAIN_DIR="${DEPS}/sysroot-macOS-${MAIN_ARCH}"
	LIST=$(find "${MAIN_DIR}" -path "${FIND}" -type f)
	OLDIFS=${IFS}
	IFS=$'\n'

	for f in ${LIST}
	do
		NAME=$(basename "${f}")

		if [ "${NAME}" == "Info.plist" ]; then
			continue # skip Info.plist
		fi

		FILE=${f/"${MAIN_DIR}"/}
		INPUTS=$(echo ${ALL_ARCHS} | xargs printf -- "${DEPS}/sysroot-macOS-%s${FILE}\n")
		OUTPUT="${BASEDIR}/Library/${FILE}"
		OUTPUT_DIR="$(dirname "${OUTPUT}")"

		if [ ! -d "${OUTPUT_DIR}" ]; then
			mkdir -p "${OUTPUT_DIR}"
		fi

		echo "Packing ${FILE}"
		echo ${ALL_ARCHS} | xargs printf -- "${DEPS}/sysroot-macOS-%s${FILE}\n" | xargs lipo -output "${OUTPUT}" -create
	done

	IFS=${OLDIFS}
}

pack_dir() {
	BASEDIR="$1"
	DIR="$2"
	SRC="${DEPS}/sysroot-macOS-${MAIN_ARCH}"
	TGT="${BASEDIR}/Library"

	rm -rf "${TGT}/${DIR}"

	if [ ! -d "$(dirname "${TGT}/${DIR}")" ]; then
		mkdir -p "$(dirname "${TGT}/${DIR}")"
	fi

	echo "Packing /${DIR}"
	cp -a "${SRC}/${DIR}" "${TGT}/${DIR}"
}

pack_all_objs "${BASEDIR}" "*/lib/*.dylib"
pack_all_objs "${BASEDIR}" "*/lib/*.a"
pack_dir "${BASEDIR}" "Frameworks" # for all the Info.plist
pack_all_objs "${BASEDIR}" "*/Frameworks/*.framework/*"
pack_dir "${BASEDIR}" "include"
pack_dir "${BASEDIR}" "lib/glib-2.0/include"
