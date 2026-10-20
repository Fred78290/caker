# Windows GPU driver (viogpudo)

The Windows ARM64 installation media carries this build of virtio-win's `viogpudo` instead of the one on the virtio-win ISO.

## Why

After a resolution change Virtualization.framework shows a corrupted picture with the stock driver (black with garbled
fragments above a width of 1024, horizontal streaks below it), although the guest renders the new mode correctly. The
driver destroys its framebuffer resource and creates the next one with the same resource id, and the host does not handle
that. This build gives every framebuffer a new id. Only that changes:

- Source: <https://github.com/Fred78290/kvm-guest-drivers-windows/tree/viogpu-fresh-framebuffer-resource-id> (one commit,
  `34014f0`, on top of `virtio-win/kvm-guest-drivers-windows` `d92b9c0`; proposed upstream).
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
| `viogpudo.sys` | `19794c39dfbebe0ef7b8a4e999c9951d574b606e48dbf571169f160e20ea8344` |
| `viogpudo.inf` | `0c585f778627ca4c063bd2c9411541f56c9cb9d893532378d9ba65eb32cb6ec6` |
| `viogpudo.cat` | `7eeeb4d5aaec48ef45a7046d1c7a24f44f736d9fbba71ab9a8d72fd288fe013f` |
| `caker-test-signing.cer` | `28bc7d826b6d086ecff28410da48527f01c1e47e033407ba84ff4e77b2fe836a` |

The driver is BSD 3-clause, like virtio-win.
