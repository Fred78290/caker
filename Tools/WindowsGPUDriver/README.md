# Windows GPU driver (viogpudo)

The Windows installation media (ARM64 and x64) carries this build of virtio-win's `viogpudo` instead of the one on the virtio-win ISO.
Intel guests show the same corruption as Apple silicon ones and report the same PCI subsystem id (`SUBSYS_00501AF4`), so the x64 build is
the same source with the same INF (see WINDOWS_INTEL_PLAN.md, Phase 4b).

## Why

After a resolution change Virtualization.framework shows a corrupted picture with the stock driver (black with garbled
fragments above a width of 1024, horizontal streaks below it), although the guest renders the new mode correctly. The
driver destroys its framebuffer resource and creates the next one with the same resource id, and the host does not handle
that. This build gives every framebuffer a new id, and disables the scanout before it destroys the old framebuffer (the
host refuses to destroy the resource a scanout is showing, which would leave it allocated; that part is WKosikowski's
suggestion on #1687, commit `1932c77` of their fork, and needs no option). Only that changes:

- Source: <https://github.com/Fred78290/kvm-guest-drivers-windows/tree/viogpu-32mib-frame-segment> (five commits, up to
  `f461ccc4`, on top of `virtio-win/kvm-guest-drivers-windows` `d92b9c0`; the first two and the scanout one are proposed upstream
  as #1687 and live on `viogpu-fresh-framebuffer-resource-id`, up to `bd2a115b`). After review the fresh ids are an option: the INF sets
  `UseFreshResourceId=1` for the PCI subsystem id Virtualization.framework gives its virtio GPU (`SUBSYS_00501AF4`), so this
  build only changes behavior there; the original code runs everywhere else.
- The third commit (`d28b2c9`) makes the smallest frame segment an option too, `MinFrameSegmentSizeMiB` (16 to 256, 16 when unset, so nothing
  changes by default) and the same INF section sets it to 32. The segment is allocated once, when the adapter starts, and a
  display mode whose surface (width x height x 4 bytes) doesn't fit it is refused (`DISP_CHANGE_BADMODE`): 16 MiB is 4.19 million
  pixels (3440x1440 doesn't fit), 32 MiB is 8.39 million (3840x2160 does). caker keeps a Windows guest's display inside it
  (`WindowsDisplayLimit`), using `WindowsGPUDriverBinaries.frameSegmentMiB`, recorded in the VM's config at install.
- The fourth commit (`efeadeb3`; `e2c7d208` on the #1687 branch) disables scanout 0 before the framebuffer is detached and destroyed, on every path. The fifth (`f461ccc4`; `bd2a115b`) sends that command with a fence and waits for the device to complete it (`CtrlQueue::DisableScanout`, up to one second, only below DISPATCH_LEVEL), as a reviewer of #1687 asked.
- Remove this directory, `WindowsGPUDriverBinaries.swift` and the `WindowsGPUDriver` use in `WindowsInstallationMedia` once a
  virtio-win release carries the fix.

## Signing

Windows loads signed kernel drivers only (ARM64 always; x64 unless test-signing is on and the driver is signed), so each build is **test-signed**
with its own self-signed certificate (`caker-test-signing.cer` in `arm64/` and in `amd64/`, the public half only; the media of a guest carries the
certificate of its architecture). The installed system therefore trusts that certificate (Root and
TrustedPublisher) and runs with test-signing on (`bcdedit /set testsigning on`), which shows a "Test Mode" watermark on the
desktop and lets the guest load any test-signed driver. `SetupComplete.cmd` does both (`WindowsInstallResources`).

## Rebuilding

On a Windows 11 machine of the target architecture (a caker VM works) with Visual Studio 2022 Build Tools (MSVC for the architecture + its
Spectre-mitigated libraries), the Windows SDK 10.0.26100 and the WDK 10.0.26100. The WDK's MSBuild toolset
(`WindowsKernelModeDriver10.0`) comes from the Build Tools component `Component.Microsoft.Windows.DriverKit.BuildTools` (since 17.11 the WDK's
VSIX is a Visual Studio component; the WDK installer itself doesn't install it into Build Tools). The x64 build was made like this on an Intel
caker VM, everything over SSH:

```
winget install -e --id Git.Git
winget install -e --id Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre"
winget install -e --id Microsoft.WindowsSDK.10.0.26100
winget install -e --id Microsoft.WindowsWDK.10.0.26100
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Component.Microsoft.Windows.DriverKit.BuildTools --quiet --norestart
```

(for ARM64 add the ARM64 tools and Spectre libraries and build with `/p:Platform=ARM64`). Then, in a checkout of the source above:

```
msbuild VirtIO\VirtioLib.vcxproj  /p:Configuration="Win11 Release" /p:Platform=x64
msbuild viogpu\viogpudo\viogpudo.vcxproj /p:Configuration="Win11 Release" /p:Platform=x64
```

(the packaging errors about `viogpuap`/`viogpusc`/`viogpures` don't matter: only `viogpudo\objfre_win11_amd64\amd64\viogpudo\`, or
`objfre_win11_arm64\arm64\viogpudo\`, is used). Then create a new code-signing certificate for that architecture
(`New-SelfSignedCertificate -Type CodeSigningCert`), sign `viogpudo.sys` and `viogpudo.cat` with `signtool sign /fd SHA256 /sha1 <thumbprint>`, export the
`.cer`, put `viogpudo.sys`, `.inf`, `.cat` and the `.cer` in `arm64/` or `amd64/`, and run `./embed.sh`. Throw the private key away
(`[System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert).Key.Delete()` with the full type name, which Windows PowerShell
doesn't resolve from the short one, then remove the certificate from the store; the key file lives in `C:\ProgramData\Microsoft\Crypto\Keys`, check it is empty).

## Files

`arm64/` (built on a caker ARM64 VM, `100.6.101.58000`):

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `aeaef89d6c9cb494c29f24361e5a22655eed0adc55e253e0d2d35be294118ee6` |
| `viogpudo.inf` | `1f1da6656601d0d0abc54b90b2d7c0bc11a035673822062d4dfcaa673a3f17ef` |
| `viogpudo.cat` | `36bbcb7dcbc685eaa9dfbd98d0c3cc1dbff771dab352d5ee262011b855b9b618` |
| `caker-test-signing.cer` | `61ac63527693ab34ecf5ace1df2e601e3083b831665a3ce31ad6d512f5b2e80a` |

`amd64/` (the same source, cross-built from that ARM64 VM with the Build Tools' x64 tools, `arm64_amd64` and `/p:Platform=x64`, which also needs the x64
Spectre libraries, `Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre`; not yet run on an Intel guest):

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `a47efaa07ae46dded5d9c572c536fd84858cf1354576166a348c98706223b371` |
| `viogpudo.inf` | `014073ece296292833d899401cbbc5fae28a3b1a4a210821633bfccb2ac5c9b1` |
| `viogpudo.cat` | `cbd4e6254bb63dc5279a2760ef5d87ea0202bb3df2cf9b709721667369d4a5c2` |
| `caker-test-signing.cer` | `6b5c7096b953514d2465c8a4651a3c39d6daf4797d809286340b02d46f7f34ec` |

The driver is BSD 3-clause, like virtio-win.
