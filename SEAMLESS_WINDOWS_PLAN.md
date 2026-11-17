# Seamless Linux windows on the macOS desktop (WSLg-style)

Status: **working prototype, both halves.** The host side (Swift, `Sources/cakedlib/Seamless/`) and the guest compositor (C/wlroots, `Tools/SeamlessCompositor/`) were run together on a real Ubuntu 26.04 arm64 Caker VM over the real vsock bridge: `weston-simple-shm` (animated) and the `foot` terminal show up as native macOS windows, typed keys reach the guest and the output is drawn back. It is now wired into the VM lifecycle (below); the cakeagent that ships the compositor is Fred78290/cakeagent#23 and is released from snapshot `ee64e17b`.

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

## Protocol (version 2)

Frame: `u32 length` (type byte + payload) + `u8 type` + payload, little endian, strings `u16 length` + UTF-8. Types `0x01...0x7F` guest to host, `0x81...0xFF` host to guest. First message must be `hello`; the host answers `helloAck` with the output scale (`120` == 1x, fractional-scale units).

Guest to host: `hello`, `windowCreate` (id, parent, toplevel/popup, popup offset, title, app id), `windowTitle`, `windowAppID`, `windowHints` (min/max size), `windowFrame`, `windowDestroy`, `cursor` (CSS cursor name).

Host to guest: `helloAck`, `output` (scale change), `windowResize` (logical size), `windowClose` (request, the guest answers `windowDestroy`), `windowFocus`, `pointerEnter/Leave/Motion/Button/Axis` (logical surface coordinates, evdev button codes; `Axis` carries a source: `continuous` trackpad pixels, `wheel` mouse notches reported to clients as discrete `value120` steps, `stop` when the fingers leave the trackpad. Version 2 added the source byte. The host still accepts a version 1 guest: it answers `helloAck` with the guest's version and never sends `Axis` to it, so such a guest works without the mouse wheel until its agent is updated; a guest newer than the host is refused), `key` (evdev code, delivered to the focused window).

`windowFrame`: buffer size in pixels + damage rectangles. Pixels are BGRA premultiplied (`wl_shm` ARGB8888 on little endian). Each rectangle is raw or an LZ4 **raw block** (what `LZ4_compress_default` writes); the guest picks per rectangle. Buffer pixels = logical size * scale / 120.

The guest is untrusted: sizes, rectangle bounds, string lengths, floats and decompressed sizes are all validated, the host caps the windows (64), the frames in flight (8) and a buffer at 40 Mpx, the socket is `0600`, and every title is prefixed `[<vm>]` so a guest cannot pass its windows off as a host application's.

## Wired into the VM lifecycle

- **Per VM option** `CakeConfig.seamless` (`config.json`, Linux guests only): `caked build/launch --seamless` (set at build time, which is what makes the cloud-init seed install the compositor), `caked configure <vm> --seamless true`, `cakectl configure` (new `ConfigureRequest.seamless`, `Configuration.seamless` in `service.proto`), a "Seamless windows" toggle in Caker's VM settings and in the VM creation wizard (Options, Linux images only; it must be chosen at creation, see above).
- **Socket device**: `CakeConfig.socketDeviceAttachments` adds `connect://vsock:5100/<vm dir>/seamless.sock` (short `/tmp` path when the VM path is too long for a `sockaddr_un`).
- **Server**: `VirtualMachine.startSeamlessWindows()` starts a `SeamlessWindowManager` once the VM runs, in any process that runs the VM: Caker.app and `caked vmrun --ui`/`--all` have an application already, a `vmrun --vnc` (what a background start uses) gets an accessory one from the manager (`SeamlessWindowManager.prepareApplication`, no Dock icon or menu bar) and `VMRun` runs its event loop, and a new guest toplevel activates it so the window comes forward. A VM run by the caked service doesn't listen (see `SeamlessTunnel` below). `didChangedStateOnStop` stops it and removes the socket.
- **Guest**: `CakeConfig.agentServiceFlags` adds `--seamless --seamless-user=<vm user> --seamless-layout=<host layout>` to `cakeagent service install` in both install scripts (cloud-init and SSH), so a freshly built VM, or an agent update, installs the compositor service. The host keyboard layout comes from `SeamlessKeyboardLayout` (macOS input source id to XKB layout, plain layouts only).
- **`caked shell`/`exec` auto-start**: a VM they start in the background (`StartHandler`, `.background`) runs plain `caked vmrun --vnc`: for a seamless VM `VMRun` runs an accessory `NSApplication` (instead of waiting on the stop promise) so the headless process can draw the guest's windows, and exits with the VM like any other. Verified: windows owned by that process, socket, PID file and windows gone after `caked stop`. Not verified: that the window really comes to front (the Mac was at the login window during the check).
- **Shell and commands run as the seamless user**: the agent runs as root, whose runtime directory (`/run/user/0`) holds no compositor socket, so a root shell or command could never open a window. `ExecuteRequest` carries a `user` (`Shell.user`, `Command.user` in `agent.proto`); `CakeConfig.seamlessUser` (the VM's user, nil without seamless windows) is what `caked shell`/`exec`, the gRPC relay (`CakeAgentConnection.execute`) and the GUI terminal (`ShellCakeAgent`) send. A root Linux agent then runs the process with that user's credentials, groups, `HOME`/`USER`/`SHELL`, terminal ownership and `XDG_RUNTIME_DIR`, plus the display variables when the compositor runs (a command doesn't source the login profile). An empty user keeps the agent's own, a non-root agent refuses another user, the macOS agent ignores it. **`caked exec` therefore no longer runs as root in a seamless VM**: use `sudo`. Needs the cakeagent with this (snapshot `93f70116`, Fred78290/cakeagent#27). Starting an app in the first seconds after boot can still lose a race with the compositor/activation environment (the D-Bus activated service then fails with \"Cannot open display\" until `systemctl --user reset-failed`).
- **Needs a cakeagent with `seamless` support** (`CAKEAGENT_SNAPSHOT`): cakeagent snapshot `ee64e17b` (Fred78290/cakeagent#23) is the first with them; an older guest agent ignores the install flags. To try it by hand: build that agent, copy it into the VM and run `cakeagent seamless run --seamless-user <user>`, then `cakeagent seamless launch -- foot`.

Verified on a freshly built VM (`caked build --alias ubuntu2604 --seamless`, agent snapshot `ee64e17b` installed by cloud-init: compositor in `/usr/libexec/caker/`, service flags in the unit, compositor connected on boot, the shell profile installed, and `gnome-terminal`, `nautilus` and `foot` typed as plain commands in an ssh login shell shown as host windows), and earlier with a VM started by a `caked vmrun --ui` built from this branch: Caker created the socket and the server, the guest compositor (run by a dev cakeagent) connected over vsock, `foot` opened as `[seamless-dev] foot`, keystrokes through the real window-focus path reached the guest shell, and stopping the VM removed the socket.

## Windows of a VM that runs under a service, possibly on another host: `SeamlessTunnel`

The VM's socket device connects to a unix socket on the VM's host, so whoever shows the windows has to listen there. A client that is not on that host (`cakectl`, talking to a `caked service` that may be remote) can't, so the stream travels over gRPC like the VNC one does:

```
guest compositor ──vsock──► socket device ──► seamless.sock ◄── caked service (SeamlessTunnel) ◄──gRPC──► cakectl seamless ──► SeamlessWindowManager
```

- **RPC**: `SeamlessTunnel(stream SeamlessStream) returns (stream SeamlessStream)`, `SeamlessStream{bytes stream}`, the VM named by the `CAKEAGENT_VMNAME` header (as `VncTunnel`). The bytes are the wire protocol above, untouched: the service never decodes them.
- **Service side** (`Sources/caked/SeamlessTunnel/SeamlessTunnel.swift`): for as long as the client's stream lasts it listens on the VM's `seamless.sock` (NIO unix-socket server, `0600`) and pipes the guest connection to the stream and back; a new guest connection replaces the previous one. The compositor retries every second, so it connects once the listener exists and again after a restart; when the client leaves, the listener and the socket go. A listener that fails (NIO gives up on an accepted socket the guest already dropped) is bound again while the client is there. Errors a client can act on are gRPC statuses with a message (`notFound`, `failedPrecondition` when seamless is off, `alreadyExists`).
- **One owner per socket**: `SeamlessServer.acquireListenerLock(for:)` is an `flock` on `<socket>.lock`, taken by `SeamlessServer.start()` and by the tunnel, so Caker.app, a `caked vmrun --ui` and a tunnel can't listen on the same guest. Probing the socket by connecting was tried first and is wrong: the listener takes the probe for the guest and drops the real session. The kernel releases the lock when the process dies.
- **A VM run by the service doesn't listen itself** (`VMRunHandler.launchedFromService`, `VirtualMachine.startSeamlessWindows()`): its windows are shown through the tunnel.
- **Caker.app** (`Sources/caker/Helpers/SeamlessTunnelSession.swift`): for every connection mode but `.app` (a local or a remote service), `VirtualMachineDocument.updateSeamlessTunnel()` keeps one `SeamlessTunnelSession` while a Linux VM with seamless windows is `.running` (called from the `status` and `virtualMachineConfig` observers, so it follows the status events whatever sends them) and stops it otherwise. The session owns the `SeamlessWindowManager` and the `SeamlessTunnelClient`, reconnects every 3 s when the stream ends (service restarted, network blip) and gives up on a permanent refusal (`notFound`, `failedPrecondition`, `alreadyExists`, ...). In `.app` mode the VM runs in the app and `VirtualMachine.startSeamlessWindows()` listens directly. Verified with a real service: Caker.app (not `.app` mode) opens the tunnel when the VM runs, a guest `gnome-terminal` started by `cakectl exec` shows as `Caker [seamless-new] Terminal`, stopping the VM removes the socket and the window, starting it again shows windows again. Not run: a remote service, the reconnect after a service restart (Caker switches back to `.app` mode when the service goes away, which drops the document, so the reconnect only covers shorter outages).
- **Client side** (`Sources/cakedlib/Seamless/SeamlessTunnelClient.swift`, `cakectl seamless <vm>`): the stream becomes one end of a `socketpair`, the other end goes to `SeamlessWindowManager.attach(fd:)` (`SeamlessServer.attach(fd:)`), so the manager works as with a local guest and needs no socket. The command runs an `NSApplication` until Ctrl-C or until the service ends the stream, and prints the service's error otherwise (`terminate` never returns to `run()`, so it is reported before).
- **Verified** with a real service (`caked service listen`) and `cakectl` on the same host: the VM started through the service (`vmrun --service`), `cakectl seamless` shows `gnome-terminal` started by `cakectl exec` as `[seamless-new] Terminal` owned by `cakectl`, a second tunnel is refused with its message while the first keeps running, an unknown or non-seamless VM is reported, Ctrl-C removes the socket. Not run: a service on another host, a client that is slower than the guest (the gRPC callback API has no flow control, so the service-to-client direction buffers in the client's write queue; the frames in flight are capped by `SeamlessServer` once the manager reads).

## The guest compositor

`Tools/SeamlessCompositor/` (`main.c`, `wire.c`, `README.md`, `caker-seamlessd.service`): a headless wlroots compositor with software (pixman) rendering.

- Each `xdg_toplevel`/`xdg_popup` is announced when it maps. On every commit of the window or any of its subsurfaces it renders the surface tree at `logical * scale` into an offscreen buffer, diffs it against the previous frame to find the changed rectangle, LZ4-compresses it and queues it (non-blocking, 64 MiB cap, then it falls back to a full frame). Updates are coalesced to ~60 fps and frame callbacks are sent after each frame.
- Host input becomes seat events: evdev keys through a virtual xkb keyboard, pointer enter/motion/button/axis hit-tested against the window's surface tree, focus through `xdg_toplevel` activation.
- Scale: the host's output scale is advertised through `wp_fractional_scale` and `preferred_buffer_scale`.
- The host draws the title bar (server-side decorations requested), maximize/fullscreen/minimize requests are acknowledged and ignored.
- It connects to `vsock:5100` (or `unix:`/`tcp:` for testing), retries every second, and re-announces every window when the host reconnects.

Verified in a Caker VM: `weston-simple-shm`, `foot`. Also checked with the agent's fixes (cakeagent#24): `gnome-terminal`, Files (Nautilus) and the snap Firefox (cakeagent#24, #25). Those need the display exported to D-Bus/systemd activation, and Firefox needs a `wayland-N` socket name (snap's AppArmor). Not exercised: popups from a real toolkit, host-initiated resize, fractional scales other than 2x, a second window.

## Not done yet / known gaps

- XWayland (X11 apps), clipboard (`wl_data_device` is advertised but selections aren't synced), client-drawn cursor images, `text-input` (IME), `xdg_activation`.
- Packaging: installing and starting `caker-seamlessd` from the cakeagent (it is built by hand in the guest for now), exposing guest `.desktop` entries.
- Not wired: a menu to launch guest `.desktop` apps from Caker, and showing windows automatically from `cakectl start`/`shell`.
- Clipboard and drag and drop (message ids are free, nothing is reserved).
- Input methods / IME and character-level text input: keys go by physical position, so the guest keyboard layout must match the host's. Cmd shortcuts handled by the host menu are not forwarded.
- Host-driven output scale changes when a window moves between displays (`output` exists, nothing sends it on a screen change).
- Rendering: each frame snapshots the whole buffer into a `CGImage`. Fine for a prototype; replace with an `IOSurface` ring and per-damage updates, and coalesce to the display refresh.
- Compression: LZ4 only. Large animated windows may want a video codec (VideoToolbox decode, software encode in the guest).
- Host app launchers (`cakectl app run <vm> firefox`, generated `.app` stubs for guest `.desktop` files).
- No accelerated 3D: Virtualization.framework gives Linux guests no GPU. A custom virtio device is the only path there, and a big project.
- Not run against a real vsock bridge, not run in the sandboxed App Store build (a socket device is created the same way, unverified).
