#!/bin/sh
# Based off of https://github.com/szanni/ios-autotools/blob/master/iconfigure
# Copyright (c) 2014, Angelo Haller
# 
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
set -e

export PATH="/usr/local/opt/bison/bin:/opt/homebrew/opt/bison/bin:/usr/bin:/usr/sbin:/bin:/Library/Apple/usr/bin:/opt/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/X11/bin:/sbin:/System/Cryptexes/App/usr/bin:/Users/fboltz/go/bin:/usr/local/bin"

# Printing coloured lines
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Knobs
MAC_SDKMINVER="13.0"

# Build environment
PLATFORM=macos
CHOST=
SDK=
SDKMINVER=

command -v realpath >/dev/null 2>&1 || realpath() {
	[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

version_check() {
	[ "$1" = "$(echo "$1\n$2" | sort -V | head -n1)" ]
}

usage () {
	echo "Usage: [VARIABLE...] $(basename $0) [-p platform] [-a architecture] [-d] [-r]"
	echo ""
	echo "  -a architecture  Target architecture. Default arm64. [armv7|armv7s|arm64|i386|x86_64]"
	echo "  -d, --download   Force re-download of source even if already downloaded."
	echo "  -r, --rebuild    Avoid cleaning build directory."
	echo ""
	echo "  VARIABLEs are:"
	echo "    NCPU           Number of CPUs to use in 'make', 0 to use all cores."
	echo "    SDKVERSION     Target a specific SDK version."
	echo "    CHOST          Configure host, set if not deducable by ARCH."
	echo ""
	echo "    CFLAGS CPPFLAGS CXXFLAGS LDFLAGS"
	echo ""
	exit 1
}

python_module_test () {
	python3 -c "import $1"
}

check_env () {
	command -v python3 >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'python3' on your host machine.${NC}"; exit 1; }
	python_module_test six >/dev/null 2>&1 || { echo >&2 "${RED}'six' not found in your Python 3 installation.${NC}"; exit 1; }
	python_module_test pyparsing >/dev/null 2>&1 || { echo >&2 "${RED}'pyparsing' not found in your Python 3 installation.${NC}"; exit 1; }
	python_module_test distutils >/dev/null 2>&1 || { echo >&2 "${RED}'distutils' not found in your Python 3 installation.${NC}"; exit 1; }
	command -v meson >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'meson' on your host machine.${NC}"; exit 1; }
	command -v msgfmt >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'gettext' on your host machine.\n\t'msgfmt' needs to be in your \$PATH as well.${NC}"; exit 1; }
	command -v glib-mkenums >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib-utils' on your host machine.\n\t'glib-mkenums' needs to be in your \$PATH as well.${NC}"; exit 1; }
	command -v glib-compile-resources >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'glib-utils' on your host machine.\n\t'glib-compile-resources' needs to be in your \$PATH as well.${NC}"; exit 1; }
	command -v gpg-error-config >/dev/null 2>&1 || { echo >&2 "${RED}You must install 'libgpg-error' on your host machine.\n\t'gpg-error-config' needs to be in your \$PATH as well.${NC}"; exit 1; }
	command -v xcrun >/dev/null 2>&1 || { echo >&2 "${RED}'xcrun' is not found. Make sure you are running on OSX."; exit 1; }
	command -v otool >/dev/null 2>&1 || { echo >&2 "${RED}'otool' is not found. Make sure you are running on OSX."; exit 1; }
	command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "${RED}'install_name_tool' is not found. Make sure you are running on OSX."; exit 1; }
	version_check "2.4" "$(bison -V | head -1 | awk '{ print $NF }')" || { echo >&2 "${RED}'bison' >= 2.4 is required. Did you install from Homebrew and updated your \$PATH variable?"; exit 1; }
}

download () {
	URL=$1
	FILE="$(basename $URL)"
	NAME="${FILE%.tar.*}"
	TARGET="$BUILD_DIR/$FILE"
	DIR="$BUILD_DIR/$NAME"
	PATCH="$PATCHES_DIR/${NAME}.patch"
	DATA="$PATCHES_DIR/data/${NAME}"
	if [ -f "$TARGET" -a -z "$REDOWNLOAD" ]; then
		echo "${GREEN}$TARGET already downloaded! Run with -d to force re-download.${NC}"
	else
		echo "${GREEN}Downloading ${URL}${NC}"
		curl -L -O "$URL"
		mv "$FILE" "$TARGET"
	fi
	if [ -d "$DIR" ]; then
		echo "${GREEN}Deleting existing build directory ${DIR}...${NC}"
		rm -rf "$DIR"
	fi
	echo "${GREEN}Unpacking ${NAME}...${NC}"
	tar -xf "$TARGET" -C "$BUILD_DIR"
	if [ -f "$PATCH" ]; then
		echo "${GREEN}Patching ${NAME}...${NC}"
		patch -d "$DIR" -p1 < "$PATCH"
	fi
	if [ -d "$DATA" ]; then
		echo "${GREEN}Patching data ${NAME}...${NC}"
		cp -r "$DATA/" "$DIR"
	fi
}

clone () {
	REPO="$1"
	COMMIT="$2"
	SUBDIRS="$3"
	NAME="$(basename $REPO)"
	DIR="$BUILD_DIR/$NAME"
	if [ -d "$DIR" -a -z "$REDOWNLOAD" ]; then
		echo "${GREEN}$DIR already downloaded! Run with -d to force re-download.${NC}"
	else
		rm -rf "$DIR"
		echo "${GREEN}Cloning ${REPO}...${NC}"
		git clone --filter=tree:0 --no-checkout "$REPO" "$DIR"
		if [ ! -z "$SUBDIRS" ]; then
			git -C "$DIR" sparse-checkout init
			git -C "$DIR" sparse-checkout set $SUBDIRS
		fi
	fi
	git -C "$DIR" checkout "$COMMIT"
}

download_all () {
	[ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR"
	download $PKG_CONFIG_SRC
	download $GLIB_SRC
	download $GPG_ERROR_SRC
	download $GCRYPT_SRC
	download $PIXMAN_SRC
	download $OPENSSL_SRC
	download $TPMS_SRC
	download $SWTPM_SRC
	download $OPUS_SRC
	download $SPICE_PROTOCOL_SRC
	download $SPICE_SERVER_SRC
	download $JSON_GLIB_SRC
	download $GST_SRC
	download $GST_BASE_SRC
	download $GST_GOOD_SRC
	download $XML2_SRC
	download $SOUP_SRC
	download $PHODAV_SRC
	download $SPICE_CLIENT_SRC
	download $ZSTD_SRC
	download $SLIRP_SRC
	if [ -z "$SKIP_USB_BUILD" ]; then
		download $USB_SRC
		download $USBREDIR_SRC
	fi
	clone $WEBKIT_REPO $WEBKIT_COMMIT "$WEBKIT_SUBDIRS"
	clone $EPOXY_REPO $EPOXY_COMMIT
	clone $VIRGLRENDERER_REPO $VIRGLRENDERER_COMMIT
	clone $LIBUCONTEXT_REPO $LIBUCONTEXT_COMMIT
}

copy_private_headers() {
	MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
	IOKIT_HEADERS_PATH="$MACOS_SDK_PATH/System/Library/Frameworks/IOKit.framework/Headers"
	OSTYPES_HEADERS_PATH="$MACOS_SDK_PATH/usr/include/libkern"
	OUTPUT_INCLUDES="$PREFIX/include"
	if [ ! -d "$IOKIT_HEADERS_PATH" ]; then
		echo "${RED}Failed to find IOKit headers in: $IOKIT_HEADERS_PATH${NC}"
		exit 1
	fi
	if [ ! -d "$OSTYPES_HEADERS_PATH" ]; then
		echo "${RED}Failed to find libkern headers in: $OSTYPES_HEADERS_PATH${NC}"
		exit 1
	fi
	echo "${GREEN}Copying private headers...${NC}"
	mkdir -p "$OUTPUT_INCLUDES"
	cp -r "$IOKIT_HEADERS_PATH" "$OUTPUT_INCLUDES/IOKit"
	rm "$OUTPUT_INCLUDES/IOKit/storage/IOMedia.h" # needed to pass QEMU check
	# patch headers
	LC_ALL=C sed -i '' -e 's/#if KERNEL_USER32/#if 0/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
	LC_ALL=C sed -i '' -e 's/#if !KERNEL_USER32/#if 1/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
	LC_ALL=C sed -i '' -e 's/#if KERNEL/#if 0/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
	LC_ALL=C sed -i '' -e 's/#if !KERNEL/#if 1/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
	LC_ALL=C sed -i '' -e 's/__UNAVAILABLE_PUBLIC_IOS;/;/g' $(find "$OUTPUT_INCLUDES/IOKit" -type f)
	mkdir -p "$OUTPUT_INCLUDES/libkern"
	cp -r "$OSTYPES_HEADERS_PATH/OSTypes.h" "$OUTPUT_INCLUDES/libkern/OSTypes.h"
}

meson_quote() {
	echo "'$(echo $* | sed "s/ /','/g")'"
}

generate_meson_cross() {
	cross="$1"
	echo "# Automatically generated - do not modify" > $cross
	echo "[properties]" >> $cross
	echo "needs_exe_wrapper = true" >> $cross
	echo "[built-in options]" >> $cross
	echo "c_args = [${CFLAGS:+$(meson_quote $CFLAGS)}]" >> $cross
	echo "cpp_args = [${CXXFLAGS:+$(meson_quote $CXXFLAGS)}]" >> $cross
	echo "objc_args = [${CFLAGS:+$(meson_quote $CFLAGS)}]" >> $cross
	echo "c_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
	echo "cpp_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
	echo "objc_link_args = [${LDFLAGS:+$(meson_quote $LDFLAGS)}]" >> $cross
	echo "[binaries]" >> $cross
	echo "c = [$(meson_quote $CC)]" >> $cross
	echo "cpp = [$(meson_quote $CXX)]" >> $cross
	echo "objc = [$(meson_quote $OBJCC)]" >> $cross
	echo "ar = [$(meson_quote $AR)]" >> $cross
	echo "nm = [$(meson_quote $NM)]" >> $cross
	echo "pkgconfig = ['$PREFIX/host/bin/pkg-config']" >> $cross
	echo "ranlib = [$(meson_quote $RANLIB)]" >> $cross
	echo "strip = [$(meson_quote $STRIP), '-x']" >> $cross
	echo "python = ['$(which python3)']" >> $cross
	echo "glib-mkenums = ['$(which glib-mkenums)']" >> $cross
	echo "glib-compile-resources = ['$(which glib-compile-resources)']" >> $cross
	echo "[host_machine]" >> $cross
	echo "system = 'darwin'" >> $cross

	case "$ARCH" in
	arm64 )
		echo "cpu_family = 'aarch64'" >> $cross
		;;
	x86_64 )
		echo "cpu_family = 'x86_64'" >> $cross
		;;
	*)
		echo "cpu_family = '$ARCH'" >> $cross
		;;
	esac

	echo "cpu = '$ARCH'" >> $cross
	echo "endian = 'little'" >> $cross
}

# Prevent contamination from host pkg-config files by building our own
build_pkg_config() {
	FILE="$(basename $PKG_CONFIG_SRC)"
	NAME="${FILE%.tar.*}"
	DIR="$BUILD_DIR/$NAME"
	pwd="$(pwd)"

	cd "$DIR"
	if [ -z "$REBUILD" ]; then
		echo "${GREEN}Configuring ${NAME}...${NC}"
		env -i CFLAGS="-Wno-error=int-conversion" ./configure --prefix="$PREFIX" --bindir="$PREFIX/host/bin" --with-internal-glib $@
	fi
	echo "${GREEN}Building ${NAME}...${NC}"
	make -j$NCPU
	echo "${GREEN}Installing ${NAME}...${NC}"
	make install
	cd "$pwd"

	export PATH="$PREFIX/host/bin:$PATH"
	export PKG_CONFIG="$PREFIX/host/bin/pkg-config"
}

build_openssl() {
	URL=$1
	shift 1
	FILE="$(basename $URL)"
	NAME="${FILE%.tar.*}"
	DIR="$BUILD_DIR/$NAME"
	pwd="$(pwd)"

	TOOLCHAIN_PATH="$(dirname $(xcrun --sdk $SDK -find clang))"
	PATH="$PATH:$TOOLCHAIN_PATH"
	CROSS_TOP="$(xcrun --sdk $SDK --show-sdk-platform-path)/Developer" # for openssl
	CROSS_SDK="$SDKNAME$SDKVERSION.sdk" # for openssl
	export CROSS_TOP
	export CROSS_SDK
	export PATH

	case $ARCH in
	arm64 )
		OPENSSL_CROSS=darwin64-arm64-cc
		;;
	x86_64 )
		OPENSSL_CROSS=darwin64-x86_64-cc
		;;
	esac

	if [ -z "$OPENSSL_CROSS" ]; then
		echo "${RED}Unsupported configuration for OpenSSL $PLATFORM, $ARCH${NC}"
		exit 1
	fi

	cd "$DIR"
	if [ -z "$REBUILD" ]; then
		echo "${GREEN}Configuring ${NAME}...${NC}"
		./Configure $OPENSSL_CROSS no-dso no-hw no-engine --prefix="$PREFIX" $@
	fi
	echo "${GREEN}Building ${NAME}...${NC}"
	make -j$NCPU
	echo "${GREEN}Installing ${NAME}...${NC}"
	make install
	cd "$pwd"
}

build () {
	if [ -d "$1" ]; then
		DIR="$1"
		NAME="$(basename "$DIR")"
	else
		URL=$1
		shift 1
		FILE="$(basename $URL)"
		NAME="${FILE%.tar.*}"
		DIR="$BUILD_DIR/$NAME"
	fi
	pwd="$(pwd)"

	cd "$DIR"
	if [ -z "$REBUILD" ]; then
		echo "${GREEN}Configuring ${NAME}...${NC}"
		./configure --prefix="$PREFIX" --host="$CHOST" $@
	fi
	echo "${GREEN}Building ${NAME}...${NC}"
	make -j$NCPU
	echo "${GREEN}Installing ${NAME}...${NC}"
	make install
	cd "$pwd"
}

meson_build () {
	SRCDIR="$1"
	shift 1
	FILE="$(basename $SRCDIR)"
	NAME="${FILE%.tar.*}"
	case $SRCDIR in
	http* | ftp* )
		SRCDIR="$BUILD_DIR/$NAME"
		;;
	esac
	MESON_CROSS="$(realpath "$BUILD_DIR")/meson.cross"
	if [ ! -f "$MESON_CROSS" ]; then
		generate_meson_cross "$MESON_CROSS"
	fi
	pwd="$(pwd)"

	cd "$SRCDIR"
	if [ -z "$REBUILD" ]; then
		rm -rf caker_build
		echo "${GREEN}Configuring ${NAME}...${NC}"
		meson caker_build --prefix="$PREFIX" --buildtype=plain --cross-file "$MESON_CROSS" "$@"
	fi
	echo "${GREEN}Building ${NAME}...${NC}"
	meson compile -C caker_build -j $NCPU
	echo "${GREEN}Installing ${NAME}...${NC}"
	meson install -C caker_build
	cd "$pwd"
}

build_angle () {
	OLD_PATH=$PATH
	PATH="$(realpath "$BUILD_DIR/depot_tools.git"):$OLD_PATH"
	pwd="$(pwd)"
	cd "$BUILD_DIR/WebKit.git/Source/ThirdParty/ANGLE"
	env -i PATH="$PATH" xcodebuild archive -archivePath "ANGLE" \
										 -scheme "ANGLE" \
										 -sdk $SDK \
										 -arch $ARCH \
										 -configuration Release \
										 WEBCORE_LIBRARY_DIR="/usr/local/lib" \
										 NORMAL_UMBRELLA_FRAMEWORKS_DIR="" \
										 CODE_SIGNING_ALLOWED=NO \
										 IPHONEOS_DEPLOYMENT_TARGET="14.0" \
										 MACOSX_DEPLOYMENT_TARGET="11.0" \
										 XROS_DEPLOYMENT_TARGET="1.0"
	# FIXME: update minver and remove this hack
	if [ "$SDK" == "iphoneos" ]; then
		find "ANGLE.xcarchive/Products/usr/local/lib/" -name '*.dylib' -exec xcrun vtool -set-version-min ios $SDKMINVER 17.2 -replace -output \{\} \{\} \;
	fi
	rsync -a "ANGLE.xcarchive/Products/usr/local/lib/" "$PREFIX/lib"
	rsync -a "include/" "$PREFIX/include"
	cd "$pwd"
	export PATH="$OLD_PATH"
}

build_qemu_dependencies () {
	meson_build $GLIB_SRC -Dtests=false -Ddtrace=disabled
	build $GPG_ERROR_SRC
	build $GCRYPT_SRC
	build $PIXMAN_SRC
	build_openssl $OPENSSL_SRC
	build $TPMS_SRC --disable-shared
	build $SWTPM_SRC --enable-shared-lib
	build $OPUS_SRC
	ZSTD_BASENAME="$(basename $ZSTD_SRC)"
	meson_build "$BUILD_DIR/${ZSTD_BASENAME%.tar.*}/build/meson"
	meson_build $GST_SRC -Dtests=disabled -Ddefault_library=both -Dregistry=false
	meson_build $GST_BASE_SRC -Dtests=disabled -Ddefault_library=both -Dgl=disabled
	meson_build $GST_GOOD_SRC -Dtests=disabled -Ddefault_library=both
	meson_build $SPICE_PROTOCOL_SRC
	meson_build $SPICE_SERVER_SRC -Dlz4=false -Dsasl=false
	meson_build $SLIRP_SRC
	# USB support
	if [ -z "$SKIP_USB_BUILD" ]; then
		build $USB_SRC
		meson_build $USBREDIR_SRC
	fi
	# GPU support
	#build_angle
	meson_build $EPOXY_REPO -Dtests=false -Dglx=no -Degl=yes
	meson_build $VIRGLRENDERER_REPO -Dtests=false -Dcheck-gl-errors=false
}

build_spice_client () {
	meson_build $LIBUCONTEXT_REPO -Ddefault_library=static -Dfreestanding=true
	meson_build $JSON_GLIB_SRC -Dintrospection=disabled
	build $XML2_SRC --enable-shared=no --without-python
	meson_build $SOUP_SRC -Dsysprof=disabled -Dtls_check=false -Dintrospection=disabled
	meson_build $PHODAV_SRC
	meson_build $SPICE_CLIENT_SRC -Dcoroutine=libucontext
}

fixup () {
	FILE=$1
	BASE=$(basename "$FILE")
	BASEFILENAME=${BASE%.*}
	LIBNAME=${BASEFILENAME#lib*}
	BUNDLE_ID="com.utmapp.${LIBNAME//_/-}"
	FRAMEWORKNAME="$LIBNAME.framework"
	BASEFRAMEWORKPATH="$PREFIX/Frameworks/$FRAMEWORKNAME"
	FRAMEWORKPATH="$BASEFRAMEWORKPATH/Versions/A"
	INFOPATH="$FRAMEWORKPATH/Resources"
	NEWFILE="$FRAMEWORKPATH/$LIBNAME"
	LIST=$(otool -L "$FILE" | tail -n +2 | cut -d ' ' -f 1 | awk '{$1=$1};1')
	OLDIFS=$IFS
	IFS=$'\n'
	echo "${GREEN}Fixing up $FILE...${NC}"
	mkdir -p "$FRAMEWORKPATH"
	mkdir -p "$INFOPATH"
	cp -a "$FILE" "$NEWFILE"
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $LIBNAME" "$INFOPATH/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFOPATH/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string $SDKMINVER" "$INFOPATH/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$INFOPATH/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$INFOPATH/Info.plist"

	ln -sf "A" "$BASEFRAMEWORKPATH/Versions/Current"
	ln -sf "Versions/Current/Resources" "$BASEFRAMEWORKPATH/Resources"
	ln -sf "Versions/Current/$LIBNAME" "$BASEFRAMEWORKPATH/$LIBNAME"

	newname="@rpath/$FRAMEWORKNAME/$LIBNAME"
	install_name_tool -id "$newname" "$NEWFILE"
	for g in $LIST
	do
		base=$(basename "$g")
		basefilename=${base%.*}
		libname=${basefilename#lib*}
		dir=$(dirname "$g")
		if [ "$dir" == "$PREFIX/lib" ]; then
			newname="@rpath/$libname.framework/Versions/A/$libname"
			install_name_tool -change "$g" "$newname" "$NEWFILE"
		fi
	done
	IFS=$OLDIFS
}

fixup_all () {
	OLDIFS=$IFS
	IFS=$'\n'
	FILES=$(find "$SYSROOT_DIR/lib" -type f -maxdepth 1 -name "*.dylib")
	for f in $FILES
	do
		fixup $f
	done
	IFS=$OLDIFS
}

remove_shared_gst_plugins () {
	find "$SYSROOT_DIR/lib/gstreamer-1.0" -name '*.dylib' -exec rm \{\} \;
}

# parse args
ARCH=
REBUILD=
REDOWNLOAD=
PLATFORM_FAMILY_NAME=

while [ "x$1" != "x" ]; do
	case $1 in
	-d | --download )
		REDOWNLOAD=y
		;;
	-r | --rebuild )
		REBUILD=y
		;;
	* )
		usage
		;;
	esac
	shift
done

if [ "x$ARCH" == "x" ]; then
	ARCH=arm64
fi
export ARCH

# Export supplied CHOST or deduce by ARCH
if [ -z "$CHOST" ]; then
	case $ARCH in
	arm64 )
		CPU=aarch64
		;;
	x86_64 )
		CPU=$ARCH
		;;
	* )
		usage
		;;
	esac
fi

CHOST=$CPU-apple-darwin
export CHOST

if [ -z "$SDKMINVER" ]; then
	SDKMINVER="$MAC_SDKMINVER"
fi
SDK=macosx
CFLAGS_TARGET="-target $ARCH-apple-macos$SDKMINVER"
PLATFORM_FAMILY_NAME="macOS"
QEMU_PLATFORM_BUILD_FLAGS="--disable-debug-info --enable-shared-lib --disable-cocoa --cpu=$CPU"

export SDK
export SDKMINVER

# Setup directories
BASEDIR="$(dirname "$(realpath $0)")"
BUILD_DIR="build-$PLATFORM_FAMILY_NAME-$ARCH"
SYSROOT_DIR="sysroot-$PLATFORM_FAMILY_NAME-$ARCH"
PATCHES_DIR="$BASEDIR/../patches"

# Include URL list
source "$PATCHES_DIR/sources"

[ -d "$SYSROOT_DIR" ] || mkdir -p "$SYSROOT_DIR"
PREFIX="$(realpath "$SYSROOT_DIR")"

# Export supplied SDKVERSION or use system default
SDKNAME=$(basename $(xcrun --sdk $SDK --show-sdk-platform-path) .platform)
if [ ! -z "$SDKVERSION" ]; then
	SDKROOT=$(xcrun --sdk $SDK --show-sdk-platform-path)"/Developer/SDKs/$SDKNAME$SDKVERSION.sdk"
else
	SDKVERSION=$(xcrun --sdk $SDK --show-sdk-version) # current version
	SDKROOT=$(xcrun --sdk $SDK --show-sdk-path) # current version
fi

if [ -z "$SDKMINVER" ]; then
	SDKMINVER="$SDKVERSION"
fi

# Set NCPU
if [ -z "$NCPU" ] || [ $NCPU -eq 0 ]; then
	NCPU="$(sysctl -n hw.ncpu)"
fi
export NCPU

# Export tools
CC="$(xcrun --sdk $SDK --find gcc) $CFLAGS_TARGET"
CPP=$(xcrun --sdk $SDK --find gcc)" -E"
CXX=$(xcrun --sdk $SDK --find g++)
OBJCC=$(xcrun --sdk $SDK --find clang)
LD=$(xcrun --sdk $SDK --find ld)
AR=$(xcrun --sdk $SDK --find ar)
NM=$(xcrun --sdk $SDK --find nm)
RANLIB=$(xcrun --sdk $SDK --find ranlib)
STRIP=$(xcrun --sdk $SDK --find strip)
export CC
export CPP
export CXX
export OBJCC
export LD
export AR
export NM
export RANLIB
export STRIP
export PREFIX

# Flags
CFLAGS="$CFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks"
CPPFLAGS="$CPPFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET"
CXXFLAGS="$CXXFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET"
OBJCFLAGS="$OBJCFLAGS -arch $ARCH -isysroot $SDKROOT -I$PREFIX/include -F$PREFIX/Frameworks $CFLAGS_TARGET"
LDFLAGS="$LDFLAGS -arch $ARCH -isysroot $SDKROOT -L$PREFIX/lib -F$PREFIX/Frameworks $CFLAGS_TARGET"
export CFLAGS
export CPPFLAGS
export CXXFLAGS
export OBJCFLAGS
export LDFLAGS

check_env
echo "${GREEN}Starting build for ${PLATFORM_FAMILY_NAME} ${ARCH} [${NCPU} jobs]${NC}"

if [ ! -f "$BUILD_DIR/BUILD_SUCCESS" ]; then
	if [ ! -z "$REBUILD" ]; then
		echo "${RED}Error, no previous successful build found.${NC}"
		exit 1
	fi
fi

if [ -z "$REBUILD" ]; then
	download_all
fi
echo "${GREEN}Deleting old sysroot!${NC}"
rm -rf "$PREFIX/"*
rm -f "$BUILD_DIR/BUILD_SUCCESS"
rm -f "$BUILD_DIR/meson.cross"
mkdir -p "$PREFIX/Frameworks"
copy_private_headers
build_pkg_config
build_qemu_dependencies
build_spice_client
fixup_all
remove_shared_gst_plugins # another hack...
echo "${GREEN}All done!${NC}"
touch "$BUILD_DIR/BUILD_SUCCESS"
