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

- Source: <https://github.com/Fred78290/kvm-guest-drivers-windows/tree/viogpu-32mib-frame-segment> (seven commits, up to
  `deef7495`, then upstream master merged (`30283f9b`, no change under `viogpu`), on top of `virtio-win/kvm-guest-drivers-windows` `d92b9c0`; the first two and the scanout one are proposed upstream
  as #1687 and live on `viogpu-fresh-framebuffer-resource-id`, up to `5cdca231`). After review the fresh ids are an option: the INF sets
  `UseFreshResourceId=1` for the PCI subsystem id Virtualization.framework gives its virtio GPU (`SUBSYS_00501AF4`), so this
  build only changes behavior there; the original code runs everywhere else.
- The third commit (`d28b2c9`) makes the smallest frame segment an option too, `MinFrameSegmentSizeMiB` (16 to 256, 16 when unset, so nothing
  changes by default) and the same INF section sets it to 64 (it was 32 until the seventh commit). The segment is allocated once, when the adapter starts, and a
  display mode whose surface (width x height x 4 bytes) doesn't fit it is refused (`DISP_CHANGE_BADMODE`): 16 MiB is 4.19 million
  pixels (3440x1440 doesn't fit), 32 MiB is 8.39 million (3840x2160 does), 64 MiB is 16.8 million (5120x3200 does). caker keeps a Windows guest's display inside it
  (`WindowsDisplayLimit`), using `WindowsGPUDriverBinaries.frameSegmentMiB`, recorded in the VM's config at install.
- The fourth commit (`efeadeb3`; `e2c7d208` on the #1687 branch) disables scanout 0 before the framebuffer is detached and destroyed, on every path. The fifth (`f461ccc4`; `bd2a115b`) sends that command with a fence and waits for the device to complete it (`CtrlQueue::DisableScanout`, up to one second, only below DISPATCH_LEVEL), as a reviewer of #1687 asked. The sixth (`8f907288`; `5cdca231`) makes `DisableScanout` return a status (success only for `RESP_OK_NODATA`): after a timeout or an error `DestroyFrameBufferObj` leaves the resource alone (it abandons the framebuffer and its id) instead of detaching and unref'ing it. Measured with a test build that logged each call to the registry: 36 calls on a Windows 11 ARM64 guest, all `RESP_OK_NODATA`, the slowest 5 ms. The seventh (`deef7495`, only on this branch: the option isn't in #1687) raises the frame segment the INF sets for Apple from 32 to 64 MiB.
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
| `viogpudo.sys` | `166d7f52447930f8f5485681de2aa99fdffdf4ed8cb86ad4ec12ff24f633fe25` |
| `viogpudo.inf` | `f90c828aeb4f83a5fd8bc7c67a3a470ffb93e617bb2d517daba4fa4de9507ae6` |
| `viogpudo.cat` | `6e7f04b414ba623d66a9fe822626ffb564fb9ca63382dcd5f52d951a2787d11c` |
| `caker-test-signing.cer` | `b21bf4b8335051dfcc33db3061afc01db6a68ab99c9a153d9b5241e46fef8b15` |

`amd64/` (the same source, cross-built from that ARM64 VM with the Build Tools' x64 tools, `arm64_amd64` and `/p:Platform=x64`, which also needs the x64
Spectre libraries, `Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre`; not yet run on an Intel guest):

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `d9d6c1b5d55830b9bbead0575330af7c74f05e1895702f5796c8b3b3a770f310` |
| `viogpudo.inf` | `4a65e97f28150be0201eee85061ca9e191f04525aaa8d13e714814d39c4ad431` |
| `viogpudo.cat` | `b9d4ae80a506a960a40d98f0f8e95ee7190a700a36987c17002ecd88b20fff0c` |
| `caker-test-signing.cer` | `98b6fd1b4b56a42993279ced1f54722409a3772b04ce948da315f9c44ce4c79d` |

The driver is BSD 3-clause, like virtio-win.
