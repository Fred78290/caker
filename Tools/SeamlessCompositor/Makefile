# Guest compositor of Caker's seamless windows. Builds on a Linux guest:
#
#   sudo apt install build-essential pkg-config libwlroots-0.19-dev wayland-protocols libwayland-dev \
#                    libwayland-bin liblz4-dev libxkbcommon-dev libpixman-1-dev
#   make
#
# Targets wlroots 0.19 (Ubuntu 26.04, Fedora 42+, Debian trixie backports).

PKGS := wlroots-0.19 wayland-server xkbcommon pixman-1 liblz4 libdrm
CFLAGS ?= -O2 -g
CFLAGS += -std=gnu11 -Wall -Wextra -Wno-unused-parameter -DWLR_USE_UNSTABLE -I. $(shell pkg-config --cflags $(PKGS))
LDLIBS := $(shell pkg-config --libs $(PKGS)) -lm

WL_PROTOCOLS := $(shell pkg-config --variable=pkgdatadir wayland-protocols)

# Protocol headers that wlroots' public headers include.
PROTO_HEADERS := xdg-shell-protocol.h xdg-decoration-unstable-v1-protocol.h fractional-scale-v1-protocol.h \
	cursor-shape-v1-protocol.h tablet-v2-protocol.h

all: caker-seamlessd

xdg-shell-protocol.h:
	wayland-scanner server-header $(WL_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml $@

xdg-decoration-unstable-v1-protocol.h:
	wayland-scanner server-header $(WL_PROTOCOLS)/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml $@

fractional-scale-v1-protocol.h:
	wayland-scanner server-header $(WL_PROTOCOLS)/staging/fractional-scale/fractional-scale-v1.xml $@

cursor-shape-v1-protocol.h:
	wayland-scanner server-header $(WL_PROTOCOLS)/staging/cursor-shape/cursor-shape-v1.xml $@

tablet-v2-protocol.h:
	wayland-scanner server-header $(WL_PROTOCOLS)/stable/tablet/tablet-v2.xml $@

main.o: main.c wire.h $(PROTO_HEADERS)
wire.o: wire.c wire.h

caker-seamlessd: main.o wire.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

clean:
	rm -f *.o caker-seamlessd $(PROTO_HEADERS)

.PHONY: all clean
