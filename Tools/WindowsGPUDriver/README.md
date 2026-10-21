# Windows GPU driver (viogpudo)

The Windows ARM64 installation media carries this build of virtio-win's `viogpudo` instead of the one on the virtio-win ISO.

## Why

After a resolution change Virtualization.framework shows a corrupted picture with the stock driver (black with garbled
fragments above a width of 1024, horizontal streaks below it), although the guest renders the new mode correctly. The
driver destroys its framebuffer resource and creates the next one with the same resource id, and the host does not handle
that. This build gives every framebuffer a new id. Only that changes:

- Source: <https://github.com/Fred78290/kvm-guest-drivers-windows/tree/viogpu-fresh-framebuffer-resource-id> (two commits,
  up to `46ffb9a`, on top of `virtio-win/kvm-guest-drivers-windows` `d92b9c0`; proposed upstream as #1687). After review
  the fresh ids are an option: the INF sets `UseFreshResourceId=1` for the PCI subsystem id Virtualization.framework
  gives its virtio GPU (`SUBSYS_00501AF4`), so this build only changes behavior there; the original code runs everywhere else.
- Remove this directory, `WindowsGPUDriverBinaries.swift` and the `WindowsGPUDriver` use in `WindowsInstallationMedia` once a
  virtio-win release carries the fix.

## Signing

Windows ARM64 loads signed kernel drivers only, so the driver is **test-signed** with a self-signed certificate
(`caker-test-signing.cer`, the public half only). The installed system therefore trusts that certificate (Root and
TrustedPublisher) and runs with test-signing on (`bcdedit /set testsigning on`), which shows a "Test Mode" watermark on the
desktop and lets the guest load any test-signed driver. `SetupComplete.cmd` does both (`WindowsInstallResources`).

## Rebuilding

On a Windows 11 ARM64 machine (a caker VM works) with Visual Studio Build Tools (MSVC ARM64 + Spectre libraries), the
Windows SDK 10.0.26100 and the WDK 10.0.26100, plus the WDK's MSBuild toolset copied into the Build Tools
(`WDK.vsix` doesn't accept Build Tools as a target: unzip it and copy `$MSBuild\Microsoft\VC\v170` over the Build Tools'):

```
msbuild VirtIO\VirtioLib.vcxproj  /p:Configuration="Win11 Release" /p:Platform=ARM64
msbuild viogpu\viogpudo\viogpudo.vcxproj /p:Configuration="Win11 Release" /p:Platform=ARM64
```

(the packaging errors about `viogpuap`/`viogpusc`/`viogpures` don't matter: only `viogpudo\objfre_win11_arm64\arm64\viogpudo\`
is used). Then create a new code-signing certificate (`New-SelfSignedCertificate -Type CodeSigningCert`), sign `viogpudo.sys`
and `viogpudo.cat` with `signtool sign /fd SHA256`, put `viogpudo.sys`, `.inf`, `.cat` and the exported `.cer` in `arm64/`, and
run `./embed.sh`. Throw the private key away.

## Files (`arm64/`)

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `ee91af5cf3c3dc8bd6e17a504825fb95caa21a6b3e6f747bf598319ceb674c0a` |
| `viogpudo.inf` | `f4a4dd629a6fe2a660da102570635e5e33052609f592a8531347d5b219a69787` |
| `viogpudo.cat` | `3d5356ad5e396699547a7d2a74542f60975cb3e1fc9f82d02d59f2c6ea301ba4` |
| `caker-test-signing.cer` | `40077402209d446d864dd816c8335288a94f085db2ad6be53abb317bd7eae972` |

The driver is BSD 3-clause, like virtio-win.
