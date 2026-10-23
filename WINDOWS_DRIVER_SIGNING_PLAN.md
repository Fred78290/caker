# Plan: production signing of the Windows guest drivers

Goal: a Windows 11 guest built by Caker loads its virtio GPU and sound drivers **without test-signing mode**: no
"Test Mode" watermark on the desktop, no throwaway certificates installed in the guest, Secure Boot-compatible.

Status: **not started, deferred on purpose.** Today both drivers are test-signed with throwaway certificates and the
guest runs in test-signing mode. That works and is documented (`CLAUDE.md`, "GPU driver, and why display resizing is
still off" and "Sound"; `wiki/provisioning.md`). This plan records what the proper solution is, what it needs from
the maintainer, and what changes in the repository once the signed packages exist, so the work can start without
re-deriving any of it. Nothing below has been tried: the Microsoft requirements are written from memory of their
current process and **must be re-checked** on learn.microsoft.com (search "attestation signing") before anyone spends
money on a certificate.

## 1. Why test-signing is a stopgap

Windows loads a kernel driver only if it is signed in a way the kernel trusts: Windows on ARM64 always requires it,
and current Windows 10/11 on x64 requires a signature from Microsoft for new drivers. Caker therefore:

- builds `viogpudo` (patched, `Tools/WindowsGPUDriver`) and `viosnd` (patched INF, `Tools/WindowsAudioDriver`) for ARM64
  and x64,
- signs each with its own throwaway certificate whose private key is discarded (`caker-test-signing.cer`,
  `caker-audio-test-signing.cer`, one per architecture),
- adds the drivers with `dism /ForceUnsigned`, and on first boot trusts the certificates (`Root` and
  `TrustedPublisher`) and runs `bcdedit /set testsigning on`.

The costs, which are what this plan removes:

- a **"Test Mode" watermark** on every Windows guest's desktop,
- the guest **trusts certificates that anyone with the same file could also use to sign a driver** (the private keys are
  discarded, so nothing new can be signed with them, but the trust is real and system-wide in that guest),
- **testsigning on** loads *any* test-signed driver the guest is given,
- software that refuses to run in test mode (some anti-cheat, DRM and security products) refuses these guests.

## 2. How a driver is properly signed

A kernel driver that loads on a normal Windows 10/11 system carries a signature **from Microsoft**. There are two
ways to get it, both through the Windows Hardware Dev Center (Partner Center, "Hardware" program):

| | Attestation signing | WHQL (HLK) certification |
|---|---|---|
| What Microsoft checks | Your identity, that the package is well formed | The driver passed the Hardware Lab Kit tests |
| Effort | Upload a CAB, wait for the result | Run the HLK suite on a test machine per architecture, submit the results |
| Covers | Windows 10/11 **client** | Client **and Server** |
| Result | Package signed by Microsoft | Package signed by Microsoft, with the WHQL logo |

For Caker, **attestation signing** is enough: Caker installs Windows 11 client only. WHQL would be needed for Windows
Server guests (the installer works on them, see `CLAUDE.md`).

What the maintainer has to provide, once:

1. An **EV code-signing certificate** (a few hundred dollars a year, issued to a person or an organization after
   identity validation; it usually lives on a hardware token or a cloud HSM). Microsoft requires it to register the
   Hardware program account and to sign the CAB that is uploaded.
2. A **Partner Center account enrolled in the Hardware program**, with that certificate registered. Identity validation
   can take days.

Cross-signing with an ordinary code-signing certificate, which used to be the way, was discontinued for new
certificates in 2021 and does not give a driver that loads on current Windows with Secure Boot.

## 3. The signing procedure (per driver, per architecture)

Everything below is repeated for `viogpudo` and `viosnd`, for ARM64 and x64, so four submissions (or two, one per
driver, if Partner Center accepts both architectures in one CAB: check).

1. **Build** the release driver with the WDK, as `Tools/WindowsGPUDriver/README.md` and `Tools/WindowsAudioDriver/README.md`
   already describe (the x64 builds are cross-built inside the ARM64 build VM).
2. **Catalog**: `inf2cat /driver:<dir> /os:10_NI_ARM64` (or the OS list for the targeted Windows builds; check the values for
   Windows 11 24H2/25H2) produces `<name>.cat`. The catalog hashes the `.sys` and `.inf`, so the INF must be final.
3. **CAB**: `makecab` the directory (`.sys`, `.inf`, `.cat`) into one `.cab`.
4. **Sign the CAB** with the EV certificate: `signtool sign /fd sha256 /tr <timestamp URL> /td sha256 /sha1 <thumbprint> driver.cab`.
5. **Submit** it in Partner Center (Hardware → Submit new hardware), choosing *attestation signing* and the target
   OS/architecture list.
6. **Download** the signed package Microsoft returns. It is signed by Microsoft, so the `.cat` and the `.sys`
   signature are replaced by theirs.
7. **Verify** on a clean guest: install with `pnputil /add-driver <inf> /install` **without** `testsigning` and without
   `ForceUnsigned`, and check `Get-AuthenticodeSignature` and the device's status (Code 0).

Constraints to plan around:

- The signature is bound to the exact binaries: **any rebuild or INF change means a new submission** and a new
  download. Treat a signed package as a release artifact, like the cakeagent snapshot.
- The EV certificate and its token **cannot be in the repository or in CI secrets that contributors share**. Signing is
  a maintainer step done by hand (or in a protected workflow); the repository only receives the signed result.
- The drivers are BSD-licensed (virtio-win's `viogpudo`, `viosnd`), so redistributing a Microsoft-signed build of the
  patched source is allowed; keep the provenance and hashes in each README as for the test-signed builds.

## 4. A cheaper route for each driver (try first)

- **Display driver**: the fix is proposed upstream as virtio-win/kvm-guest-drivers-windows#1687. virtio-win's releases
  are WHQL-signed by Red Hat. If the merged change contains what Caker needs (a fresh resource id per framebuffer, the
  `UseFreshResourceId` option and the model line for Apple's subsystem id `SUBSYS_00501AF4`, and the frame-segment
  option from the `viogpu-32mib-frame-segment` branch), **Caker can drop its own build and use the virtio-win ISO's
  driver**, which is already downloaded for the other drivers. No certificate, no submission. This is the preferred
  end state and the reason the patched driver is documented as temporary.
- **Sound driver**: `viosnd` (317764920/viosnd) has no WHQL-signed releases and virtio-win's ISO has no sound driver
  (upstream issue 929). If the Apple model line is merged (317764920/viosnd#1) and its author, or virtio-win, ships a
  signed build, use that. Otherwise this driver is the one that really needs our own submission.

So the minimum real work is probably **one driver (sound), two architectures**; the display driver may need none.

## 5. What changes in the repository when signed packages exist

All of it is about *removing* the test-signing path from the default install. Keep it available for developers who
rebuild a driver (the READMEs explain how), behind an explicit option.

| Where | Change |
|---|---|
| `Tools/WindowsGPUDriver/{arm64,amd64}`, `Tools/WindowsAudioDriver/{arm64,amd64}` | Replace `.sys`/`.inf`/`.cat` with Microsoft-signed ones, delete `caker-*-test-signing.cer`, update hashes, provenance and the submission id in each README; `embed.sh` regenerates `WindowsGPUDriverBinaries.swift` / `WindowsAudioDriverBinaries.swift` without the `certificate` field |
| `WindowsInstallationMedia.populate` | stop writing the certificates onto the media; keep adding the driver folders |
| `WindowsInstallResources.installScript` (`install.cmd`) | drop `dism /ForceUnsigned` for the signed drivers (keep it only for a developer build), stop copying the certificates |
| `WindowsInstallResources.setupComplete` (`SetupComplete.cmd`) | remove the `certutil -addstore` and `bcdedit /set testsigning on` blocks (`GPUDRV`, `AUDIORS`); keep `pnputil /scan-devices` and the marker, with `gpudriver=`/`audio=` reporting the driver's state instead of the certificate steps |
| **The display-following switch** | `SetupComplete.cmd` sets `HKLM\Software\Caker\FollowDisplaySize` **when `caker-test-signing.cer` is on the media** (that file is how it recognises "the guest has caker's patched driver"). Once the certificate is gone, that test must use another signal (a file the media still carries, or a marker written by `populate`), or display following silently turns off. If the upstream driver replaces ours, the condition becomes "the driver has the fix" and needs its own check |
| `WindowsGPUDriverBinaries`, `WindowsArchitecture.usesCakerGPUDriver` | follow the decision in section 4 (our signed build, or the virtio-win one) |
| `WindowsInstaller` | adjust the "Windows setup finished, but the GPU/sound driver may not load" warnings to the new markers |
| Tests (`WindowsGuestTests`) | the tests that assert a certificate on each driver package and the `certutil`/`testsigning` lines in the setup script change with it |
| Docs | `CLAUDE.md`, `wiki/provisioning.md` (EN/FR), `docs/` (regenerated), the Medium article's "Test Mode" paragraph and the PR descriptions no longer mention test-signing or the watermark |

Guests installed **before** the change keep test-signing mode and their trusted certificates. Updating their driver
in place is the same stop-the-VM-hard problem as before (a running driver swap hard-stops the VM) and is out of scope;
say so in the release notes rather than trying.

## 6. Risks and fallbacks

- **No EV certificate or Partner Center account**: nothing here can start; stay on test-signing, which is already
  documented and works. This plan costs nothing while it is not executed.
- **Attestation is refused** (for instance because of the INF, or the driver's declared capabilities): Microsoft's
  report says why; fix and resubmit. A fallback is the full HLK route, which is far more work.
- **A new Windows build rejects the signed driver** (stricter driver requirements, such as HVCI compatibility on
  Windows 11 Secure Core PCs): check the driver against the HVCI readiness tooling when submitting.
- **Upstream moves first**: if virtio-win ships the display fix, the work shrinks to the sound driver, or to nothing if
  that is signed upstream too. Re-read section 4 before starting.
- **Secure Boot**: this plan removes test mode, it does not make the guest Secure Boot-ready. The guest's boot chain
  also loads Caker's own UEFI driver (`Tools/WindowsEFI`), which is not signed for Secure Boot, and nothing here has
  been checked with Secure Boot on. Treat that as a separate question.

## 7. Acceptance criteria

- A fresh `--autoinstall` of Windows 11 ARM64 and x64 reaches a desktop with **no "Test Mode" watermark** and
  `bcdedit /enum` shows no `testsigning Yes`.
- No Caker-created certificate in the guest's `Root` or `TrustedPublisher` stores.
- Display (resizing included), sound and the other drivers behave as in the current test-signed install (the checks
  recorded in `CLAUDE.md` and the PR #147 description).
- `display=0` is still reported and display following still works (section 5, the switch).
- `swift test` is green with the updated Windows tests.
