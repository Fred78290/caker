# Windows audio driver (viosnd)

The Windows installation media (ARM64 and x64) carries this virtio-snd driver, so a Windows guest has sound. Virtualization.framework
exposes its audio as a virtio-snd device (`PCI\VEN_1AF4&DEV_1059&SUBSYS_00591AF4`, "Multimedia Audio Controller" in Device Manager),
and Windows has no driver for it: neither Windows nor the virtio-win ISO has one (see
[virtio-win issue 929](https://github.com/virtio-win/kvm-guest-drivers-windows/issues/929)).

## Source

- Upstream: <https://github.com/317764920/viosnd> (BSD 3-clause, like virtio-win; a PortCls/WaveRT driver on top of virtio-win's
  `VirtIO` library), at `f8101c4`.
- Fork: <https://github.com/Fred78290/viosnd/tree/apple-render-only> (one commit, `48101a6`, on top of it).

The change: Virtualization.framework's sound device has playback streams only, and the driver by default wants both a playback and a
capture stream, so it stopped at start (Code 10, `STATUS_DEVICE_CONFIGURATION_ERROR`, `LastInitStage=MissingCaptureStream` in the
device's `Device Parameters` key). The INF gets a model line for the Apple subsystem id that sets `EndpointRole` to 0 (playback only,
the driver's own option); every other device keeps the original behavior (both).

Checked on a Windows 11 ARM64 guest: the device starts, Windows shows "Speakers (XCB VirtIO Audio Device)", and a 440 Hz tone played
through it is heard on the host. The driver's own log shows `SET_PARAMS`, `PREPARE` and `START` answered OK (`0x8000`) and the stream
running at 48 kHz stereo 16-bit in real time (the device accepts 48 and 96 kHz, S16/S32/float). The x64 build is the same source and
INF, cross-built; it has not run on an Intel guest.

The host has to give the output stream a sink (`VZHostAudioOutputStreamSink`, `VirtualMachine.swift`): without one Virtualization.framework
accepts the guest's playback and discards it, which looks exactly like a driver that does nothing.

Capture (microphone) is not offered: it needs an input stream (`VZVirtioSoundDeviceInputStreamConfiguration`) and the host's microphone
permission. With one, the Apple model line would have to go (or `EndpointRole` be 2).

## Signing

The same as the GPU driver (`../WindowsGPUDriver/README.md`): each build is test-signed with its own throwaway certificate
(`caker-audio-test-signing.cer`, public half only), which setup adds to `Root` and `TrustedPublisher`, and the guest runs in
test-signing mode (already the case for the GPU driver). The private keys were deleted after signing.

## Rebuilding

On a Windows 11 caker VM with the same tools as for the GPU driver (Visual Studio 2022 Build Tools with the target architecture's
MSVC and Spectre libraries, SDK and WDK 10.0.26100, `Component.Microsoft.Windows.DriverKit.BuildTools`), in a checkout of the fork:

```
msbuild VirtIO\VirtioLib.vcxproj  /p:Configuration="Win11 Release" /p:Platform=ARM64
msbuild viosnd\sys\viosnd.vcxproj /p:Configuration="Win11 Release" /p:Platform=ARM64
```

(`/p:Platform=x64` and `vcvarsall arm64_amd64` for the x64 build, from an ARM64 VM.) The package is `viosnd\sys\viosnd\`
(`viosnd.sys`, `.inf`, `.cat`). Sign `viosnd.sys` and `viosnd.cat` with a new code-signing certificate
(`signtool sign /fd SHA256 /sha1 <thumbprint> /sm`), export the `.cer`, delete the private key, put the four files in `arm64/`
or `amd64/` and run `./embed.sh`.

## Files

| Arch | File | SHA-256 |
|---|---|---|
| arm64 | `viosnd.sys` | `2bdb16bf0d640835b383f9a6d0d0d069247eb2a33054370aecfab73bcea89a12` |
| arm64 | `viosnd.inf` | `2cac29d8d687d715bf46d9369102fb87707a0e78e2e7751478d69216dc49acf4` |
| arm64 | `viosnd.cat` | `ef47b0760eee9c49962eb79e61ce85d3b360fb15ea5daf012650350c6b5371ce` |
| arm64 | `caker-audio-test-signing.cer` | `5c463eb02a15fdbd582ec51f19bffea7d1047b6d4e607d0c554b5f9debff6dfc` |
| amd64 | `viosnd.sys` | `28e764eaf709d6f5ab4e0be0581ccb65ad6a9fe713ef070e0980e8a4d3c58067` |
| amd64 | `viosnd.inf` | `82d11d313dac2d5ccdcbd94eb05874b3a86b9b153ee84b51ba19b02070df128c` |
| amd64 | `viosnd.cat` | `2753536398d092eb45b5df23ee873cbd65f78e52357e214bf56a1a5c1c3a3bf1` |
| amd64 | `caker-audio-test-signing.cer` | `8a71b0fc20525c311d24d4dd9790709be102f493dcf9d52c7d2bae2766a71fd9` |
