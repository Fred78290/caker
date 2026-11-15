# Seamless Linux windows on the macOS desktop (WSLg-style)

Status: **working prototype, both halves.** The host side (Swift, `Sources/cakedlib/Seamless/`) and the guest compositor (C/wlroots, `Tools/SeamlessCompositor/`) were run together on a real Ubuntu 26.04 arm64 Caker VM over the real vsock bridge: `weston-simple-shm` (animated) and the `foot` terminal show up as native macOS windows, typed keys reach the guest and the output is drawn back. It is now wired into the VM lifecycle (below); the cakeagent that ships the compositor is Fred78290/cakeagent#23 and is not released yet.

## Idea

WSLg runs Weston with an RDP backend in the guest; every Wayland window becomes an RDP RemoteApp window on the Windows host. Caker does the same without RDP: a compositor in the guest streams one pixel buffer per toplevel/popup over **vsock**, the host shows each in its own `NSWindow` and sends input back.

A custom virtio device (macOS 27) is *not* needed: vsock is upstream in every guest kernel, already attached by Caker, and fast enough for damage rectangles. A custom device would only matter later for zero-copy buffers or GPU acceleration, and it needs a guest kernel driver on every distro.

## What exists

| Piece | File |
|---|---|
| Wire protocol, codec, incremental stream decoder, LZ4 rectangles | `Sources/cakedlib/Seamless/SeamlessProtocol.swift` |
| Host copy of a window's pixels (damage apply, immutable snapshots) | `SeamlessSurface.swift` |
| Unix-socket server, handshake, backpressure | `SeamlessServer.swift` |
| `NSWindow` per toplevel, popups as child panels, input forwarding, cursors | `SeamlessWindowManager.swift` |
| macOS key code to Linux evdev | `SeamlessKeyMap.swift` |
| Reference guest (animated window, popup on right click) | `SeamlessDemoGuest.swift` |
| Developer command: `caked seamless-demo [--no-guest] [--socket path]` | `Sources/caked/Commands/SeamlessDemo.swift` |
| Tests (17) | `Tests/CakerTests/SeamlessWindowTests.swift` |

Try it: `caked seamless-demo` opens a native window titled `[demo] Seamless demo` showing the fake guest's animated content. Right click opens a popup, closing the window ends the demo.

### Plumbing into a VM, no VM code changes

The existing socket device bridges guest-initiated vsock connections to a host unix socket:

```
connect://vsock:5100/<path to the seamless socket>
```

The guest compositor connects to vsock port `5100` (`SeamlessProtocol.defaultVsockPort`), the bridge in `VirtualSocketDevices.swift` forwards it to the socket `SeamlessServer` listens on.

## Protocol (version 1)

Frame: `u32 length` (type byte + payload) + `u8 type` + payload, little endian, strings `u16 length` + UTF-8. Types `0x01...0x7F` guest to host, `0x81...0xFF` host to guest. First message must be `hello`; the host answers `helloAck` with the output scale (`120` == 1x, fractional-scale units).

Guest to host: `hello`, `windowCreate` (id, parent, toplevel/popup, popup offset, title, app id), `windowTitle`, `windowAppID`, `windowHints` (min/max size), `windowFrame`, `windowDestroy`, `cursor` (CSS cursor name).

Host to guest: `helloAck`, `output` (scale change), `windowResize` (logical size), `windowClose` (request, the guest answers `windowDestroy`), `windowFocus`, `pointerEnter/Leave/Motion/Button/Axis` (logical surface coordinates, evdev button codes), `key` (evdev code, delivered to the focused window).

`windowFrame`: buffer size in pixels + damage rectangles. Pixels are BGRA premultiplied (`wl_shm` ARGB8888 on little endian). Each rectangle is raw or an LZ4 **raw block** (what `LZ4_compress_default` writes); the guest picks per rectangle. Buffer pixels = logical size * scale / 120.

The guest is untrusted: sizes, rectangle bounds, string lengths, floats and decompressed sizes are all validated, the host caps the windows (64), the frames in flight (8) and a buffer at 40 Mpx, the socket is `0600`, and every title is prefixed `[<vm>]` so a guest cannot pass its windows off as a host application's.

## Wired into the VM lifecycle

- **Per VM option** `CakeConfig.seamless` (`config.json`, Linux guests only): `caked configure <vm> --seamless true`, `cakectl configure` (new `ConfigureRequest.seamless`, `Configuration.seamless` in `service.proto`), and a "Seamless windows" toggle in Caker's VM settings.
- **Socket device**: `CakeConfig.socketDeviceAttachments` adds `connect://vsock:5100/<vm dir>/seamless.sock` (short `/tmp` path when the VM path is too long for a `sockaddr_un`).
- **Server**: `VirtualMachine.startSeamlessWindows()` starts a `SeamlessWindowManager` once the VM runs, in a process that can show windows (Caker.app, or `caked vmrun --ui`); a headless `caked` logs that it can't. `didChangedStateOnStop` stops it and removes the socket.
- **Guest**: `CakeConfig.agentServiceFlags` adds `--seamless --seamless-user=<vm user> --seamless-layout=<host layout>` to `cakeagent service install` in both install scripts (cloud-init and SSH), so a freshly built VM, or an agent update, installs the compositor service. The host keyboard layout comes from `SeamlessKeyboardLayout` (macOS input source id to XKB layout, plain layouts only).
- **Needs a cakeagent with `seamless` support** (`CAKEAGENT_SNAPSHOT`): until Fred78290/cakeagent#23 is merged and released, a guest agent doesn't know the flags. To try it by hand: build that agent, copy it into the VM and run `cakeagent seamless run --seamless-user <user>`, then `cakeagent seamless launch -- foot`.

Verified with a VM started by a `caked vmrun --ui` built from this branch: Caker created the socket and the server, the guest compositor (run by a dev cakeagent) connected over vsock, `foot` opened as `[seamless-dev] foot`, keystrokes through the real window-focus path reached the guest shell, and stopping the VM removed the socket.

## The guest compositor

`Tools/SeamlessCompositor/` (`main.c`, `wire.c`, `README.md`, `caker-seamlessd.service`): a headless wlroots compositor with software (pixman) rendering.

- Each `xdg_toplevel`/`xdg_popup` is announced when it maps. On every commit of the window or any of its subsurfaces it renders the surface tree at `logical * scale` into an offscreen buffer, diffs it against the previous frame to find the changed rectangle, LZ4-compresses it and queues it (non-blocking, 64 MiB cap, then it falls back to a full frame). Updates are coalesced to ~60 fps and frame callbacks are sent after each frame.
- Host input becomes seat events: evdev keys through a virtual xkb keyboard, pointer enter/motion/button/axis hit-tested against the window's surface tree, focus through `xdg_toplevel` activation.
- Scale: the host's output scale is advertised through `wp_fractional_scale` and `preferred_buffer_scale`.
- The host draws the title bar (server-side decorations requested), maximize/fullscreen/minimize requests are acknowledged and ignored.
- It connects to `vsock:5100` (or `unix:`/`tcp:` for testing), retries every second, and re-announces every window when the host reconnects.

Verified in a Caker VM: `weston-simple-shm`, `foot`. Not exercised: popups from a real toolkit, host-initiated resize, fractional scales other than 2x, a second window.

## Not done yet / known gaps

- XWayland (X11 apps), clipboard (`wl_data_device` is advertised but selections aren't synced), client-drawn cursor images, `text-input` (IME), `xdg_activation`.
- Packaging: installing and starting `caker-seamlessd` from the cakeagent (it is built by hand in the guest for now), exposing guest `.desktop` entries.
- Headless `caked` (service) VMs can't show windows: the stream would have to travel over gRPC to Caker.app like the VNC tunnel does. Also not wired: a `--seamless` build/launch option (use `configure`), the VM creation wizard, a menu to launch guest `.desktop` apps from Caker.
- Clipboard and drag and drop (message ids are free, nothing is reserved).
- Input methods / IME and character-level text input: keys go by physical position, so the guest keyboard layout must match the host's. Cmd shortcuts handled by the host menu are not forwarded.
- Host-driven output scale changes when a window moves between displays (`output` exists, nothing sends it on a screen change).
- Rendering: each frame snapshots the whole buffer into a `CGImage`. Fine for a prototype; replace with an `IOSurface` ring and per-damage updates, and coalesce to the display refresh.
- Compression: LZ4 only. Large animated windows may want a video codec (VideoToolbox decode, software encode in the guest).
- Host app launchers (`cakectl app run <vm> firefox`, generated `.app` stubs for guest `.desktop` files).
- No accelerated 3D: Virtualization.framework gives Linux guests no GPU. A custom virtio device is the only path there, and a big project.
- Not run against a real vsock bridge, not run in the sandboxed App Store build (a socket device is created the same way, unverified).
