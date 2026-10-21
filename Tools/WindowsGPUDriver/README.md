# Windows GPU driver (viogpudo)

The Windows installation media (ARM64 and x64) carries this build of virtio-win's `viogpudo` instead of the one on the virtio-win ISO.
Intel guests show the same corruption as Apple silicon ones and report the same PCI subsystem id (`SUBSYS_00501AF4`), so the x64 build is
the same source with the same INF (see WINDOWS_INTEL_PLAN.md, Phase 4b).

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
(`[RSACertificateExtensions]::GetRSAPrivateKey($cert).Key.Delete()`, then remove the certificate from the store).

## Files

`arm64/`:

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `ee91af5cf3c3dc8bd6e17a504825fb95caa21a6b3e6f747bf598319ceb674c0a` |
| `viogpudo.inf` | `f4a4dd629a6fe2a660da102570635e5e33052609f592a8531347d5b219a69787` |
| `viogpudo.cat` | `3d5356ad5e396699547a7d2a74542f60975cb3e1fc9f82d02d59f2c6ea301ba4` |
| `caker-test-signing.cer` | `40077402209d446d864dd816c8335288a94f085db2ad6be53abb317bd7eae972` |

`amd64/` (built from the same source, `100.6.101.58000`):

| File | SHA-256 |
|---|---|
| `viogpudo.sys` | `d777b7fb4e184cddc00438d9034435e64fe217e76a1bcbdc7bbcd309b97ea878` |
| `viogpudo.inf` | `7b6c4a7363c31a1d0e8f90284ce7790c6663f4d292413775b15746d46a4ac2c8` |
| `viogpudo.cat` | `ee522ee8e04fb4437056acdef466ddcae4c35afe7f47e2b4d78237e42b980b9d` |
| `caker-test-signing.cer` | `863a40b12111119f95bdc3d6dc380c89f9b36c75773f0e61547c838ea0bf54fc` |

The driver is BSD 3-clause, like virtio-win.
