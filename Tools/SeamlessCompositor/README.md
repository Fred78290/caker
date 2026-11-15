# caker-seamlessd

Guest half of Caker's seamless windows: a headless Wayland compositor (wlroots 0.19, software rendering) that streams
every toplevel and popup to the macOS host over vsock and feeds the host's keyboard and pointer back to the clients.
The host half is `Sources/cakedlib/Seamless/`; the protocol is described in `SEAMLESS_WINDOWS_PLAN.md`.

## Build

```sh
sudo apt install build-essential pkg-config libwlroots-0.19-dev wayland-protocols libwayland-dev \
                 libwayland-bin liblz4-dev libxkbcommon-dev libpixman-1-dev libdrm-dev
make && sudo install caker-seamlessd /usr/local/bin/
```

Needs wlroots 0.19 (Ubuntu 26.04 has it).

## Use

The VM needs the vsock bridge to the host socket (`caked launch ... --socket connect://vsock:5100/<host socket path>`),
and a host process listening on that socket (`caked seamless-demo --no-guest --socket <path>` for now).

```sh
caker-seamlessd -- foot            # starts foot with WAYLAND_DISPLAY set, exits with it
caker-seamlessd --socket caker-seamless &   # or run it as a service (caker-seamlessd.service)
WAYLAND_DISPLAY=caker-seamless foot
```

Options: `--connect vsock:PORT|unix:/path|tcp:host:port` (default `vsock:5100`; unix/tcp are for testing), `--socket NAME`,
`-v`. It reconnects every second until the host is there, and re-announces its windows when the host comes back.

Keyboard layout: the host sends physical keys (evdev codes), the guest's layout applies. Set `XKB_DEFAULT_LAYOUT` (and
`_VARIANT`) to the host's.

`SEAMLESS_FORCE_FOCUS=1` gives keyboard focus to every new toplevel, for hosts that can't report window focus.

## Verified

Ubuntu 26.04 arm64 guest in Caker, host `caked seamless-demo --no-guest` over the real vsock bridge:
`weston-simple-shm` (animated) and `foot` (a shell: typed keys reach the guest, output is drawn back).

## Not done

XWayland (X11 apps), clipboard, client-drawn cursor images, IME (`text-input`), popup grabs against real toolkits
(code exists, untested), `wl_output` changes when the host moves a window between displays, GPU acceleration.
