# Plan: unattended Windows 11 install on Intel Macs

Goal: `caked build my-win11 iso:///path/to/Win11_x64.iso --autoinstall` produces a Windows 11 **x64** VM on an
**Intel Mac**, with the same result as the Apple-silicon path (Windows 11 ARM): display, network, shared folders
(WinFsp + virtio-fs), virtio-vsock, and the cakeagent service reachable over vsock with mutual TLS.

Status: **phase 1 is implemented and unit-tested (`WindowsArchitecture`); nothing has been booted on Intel yet.** Everything marked *unknown* below has to be
found out on a real Intel Mac before the code that depends on it is written. The Apple-silicon implementation
is documented in `CLAUDE.md` ("Windows 11 for ARM is installed by `WindowsInstaller`…") and `wiki/provisioning.md`;
this plan assumes you have read the first one.

Non-goals: Windows 11 ARM on an Intel Mac (impossible without emulation), Windows 10, a TPM (same limits as ARM:
Virtualization.framework has no ACPI/TPM hook), non-English ISOs (same as ARM), the App Store build.

## 1. What carries over unchanged, what is ARM-specific

Architecture-independent (reuse as is): the GPT install media layout (`WindowsInstallationMedia`), the pure-Swift
`WIMArchive`/`LZXDecompressor`, `winpeshl.ini`/`pe.cmd`/`install.cmd` (diskpart, `dism /Apply-Image`,
`dism /Add-Driver`, `bcdboot`), the first-boot marker protocol, WinFsp (one MSI covers x64/ARM64; confirm with
`msiexec` logs), the cakeagent install in `SetupComplete.cmd`, vsock attachment for Windows guests, NVMe system disk +
USB install media, `Utilities.cakeagentWindowsBinary` (already picks `Architecture.current()`, and the release has
`cakeagent-windows-amd64.exe`).

ARM-specific today (found by grep, every one needs a per-guest-architecture value):

| Where | ARM value | x64 value to use |
|---|---|---|
| `WindowsInstallationMedia.validate` | requires `efi/boot/bootaa64.efi` | `bootx64.efi` |
| `WindowsInstallationMedia.populate` | renames `bootaa64.efi` → `windows.efi`, writes loader as `bootaa64.efi` | same with `bootx64.efi` |
| `WindowsInstallResources.installScript` | `S:\EFI\BOOT\BOOTAA64.EFI` | `BOOTX64.EFI` |
| `WindowsInstallResources.unattend` | `processorArchitecture="arm64"` (3 places) | `amd64` |
| virtio-win driver folders | `<driver>/w11/ARM64`, `viofs/w11/ARM64/virtiofs.exe` | `<driver>/w11/amd64` (confirm on the ISO) |
| `Tools/WindowsEFI` | `-target aarch64-unknown-windows`, embedded as `WindowsEFIBinaries` | a second set built with `x86_64-unknown-windows` (only if step 0 says the shim is needed) |
| `GuestPlateform.enableWindowsCPUFeatures` | private PMU / fine-grained-traps selectors, unconditional | arm64 only; probably absent or meaningless on Intel |
| GPU driver | ARM64 guests get caker's patched `viogpudo` (`Tools/WindowsGPUDriver/arm64`, test-signed, opt-in through the INF for Apple's PCI subsystem id, `WindowsArchitecture.usesCakerGPUDriver`) and the display script | nothing built yet: stock amd64 driver from the ISO until Phase 4b says otherwise |
| error strings | "…Windows on ARM installation ISO", "no ARM64 %@ driver" | architecture-neutral, with French translations |

## 2. Unknowns to settle first (step 0, no product code)

Each one decides whether later phases exist. Record the answers in this file when known.

1. **Does the toolchain run on the Intel Mac?** `Package.swift` is `swift-tools-version:6.4` and the UI code has
   `macOS 27` availability branches; Intel Macs stop at macOS 26. If the repo can't be built there, build on an
   Apple-silicon Mac with `swift build --arch x86_64` (supported since PR #131) or an `xcodebuild` for
   `x86_64`, sign with the virtualization entitlement, and copy `caked.app` over. Everything below works either way.
2. **Does Windows 11 x64 boot under Virtualization.framework on Intel at all?** Apple documents Linux guests on
   Intel; Windows is not documented on either architecture. Spike: boot a stock Windows 11 x64 ISO with a minimal
   `VZGenericPlatformConfiguration` + `VZEFIBootLoader` + USB mass storage and see whether Windows Boot Manager
   starts. If it doesn't, stop here and document "unsupported on Intel" instead of building more.
3. **Does the Intel firmware give Windows a usable framebuffer?** On Apple silicon the firmware exposes a Blt-only
   GOP, so Windows draws into null and the VM dies ("internal virtualization error"); `Tools/WindowsEFI/framebuffer.c`
   replaces the GOP. The Intel firmware may behave differently. Test by booting the spike *without* the shim: if
   Windows starts and the screen shows the boot logo, `framebuffer.efi`/`loader.efi` are not needed on Intel and
   phase 2 is dropped (the loader indirection then goes too, so Windows Boot Manager stays at `bootx64.efi`).
4. **Does Windows need a PMU/trap workaround on Intel?** The ARM-only private setters exist because Boot Manager
   never ran without them. On x64 try without any private API first; only if it fails look for an Intel equivalent.
5. **Does a guest reboot stop the VM on Intel too?** (On ARM VZ stops the VM when the guest reboots, which is why
   `WindowsInstaller` restarts until `SetupComplete.cmd` has written its marker.) Same loop works if so; if the VM
   reboots by itself the loop only needs fewer runs.
6. **virtio-win layout for amd64**: `ls` the ISO for `viostor`, `viogpudo`, `NetKVM`, `viorng`, `viofs`, `viosock`
   under `w11/amd64`, and `viofs/w11/amd64/virtiofs.exe`. Also check which of these Windows needs at all (NVMe is
   inbox, so `viostor` is only extra).
7. **Windows 11 x64 CPU requirements at runtime**: Setup's checks are bypassed by applying the image with DISM,
   but 24H2+ needs POPCNT/SSE4.2/CMPXCHG16B and refuses to boot on older CPUs. Check the Intel Mac's CPU and what
   Virtualization.framework exposes (`coreinfo`/`wmic cpu` once it boots).
8. **Does `viosock` work on x64 under VZ's vsock device?** Likely (same virtio device), but verify with the
   `vsock=running` marker, then the agent probe in section 5.

Answer to 1 (Intel Mac, macOS 26, Xcode 26.3, Swift 6.4.0 from swiftly): the repo builds only after bumping `swift-async-algorithms`.
The pinned `main` revision `6c050d5e` fails with a region-isolation error in `MultiProducerSingleConsumerAsyncChannel+Internal.swift`
(`takeSending`); `cbde9aed` (current `main`) builds, and `swift test --filter WindowsGuestTests` passes (37 tests, including one against
the real `Windows11_Client_x64_en-us_26300_9457.iso`, which has only `efi/boot/bootx64.efi`). `Package.resolved` in the repo was not changed.

Gate: if 1 can't be resolved or 2 fails, the rest of this plan is dropped.

## 3. Phases

Phases 1, 3 and 5 can be implemented and unit-tested on any Mac (including the Apple-silicon one this feature was
built on); only the checkpoints in phases 0, 2 and 4 need the Intel Mac.

### Phase 1 — a `WindowsArchitecture` value (testable anywhere)
- Add `enum WindowsArchitecture { case arm64, amd64 }` in `Sources/cakedlib/Windows/` with: `bootFile` (`bootaa64.efi`/`bootx64.efi`),
  `removableBootPath`, `virtioFolder` (`ARM64`/`amd64`), `unattendArchitecture` (`arm64`/`amd64`), `agentSuffix`.
- Detect it from the ISO (which of the two boot files exists; reject an ISO whose architecture the host can't run:
  Intel host → `amd64` only, Apple silicon → `arm64` only) instead of hard-coding ARM in `validate`.
- Thread it through `WindowsInstallationMedia.create/populate`, `WindowsInstallResources` (make `installScript` and
  `unattend` take it; keep CRLF handling), and the error strings (neutral wording + French).
- Gate `enableWindowsCPUFeatures` with `#if arch(arm64)` (and, if step 4 finds something on Intel, the x64 equivalent
  behind `responds(to:)`, never an unconditional private call).
- Tests (`Tests/CakerTests/WindowsGuestTests.swift`): both architectures render the right boot path, `processorArchitecture`
  and driver folder; an ISO fixture tree with only `bootx64.efi` validates as amd64; the wrong-host combination throws.
- `swift build --arch x86_64` and `swift test` stay green.

### Phase 2 — x64 EFI helpers (built; whether Intel needs them is still step 3)
Done: the Makefile builds `x86_64-unknown-windows` (`-mno-red-zone`) next to AArch64, `WindowsEFIBinaries` has per-architecture constants, tests check the PE `Machine`
field. The ARM64 output is byte-identical to before. **Not run on Intel firmware**: the C sources were not changed beyond a comment, and `RegisterDriverOption` / the
timer callback are unverified on x64. `WindowsArchitecture.usesFramebufferShim` is true for both; set it false for `.amd64` to run step 3's no-shim experiment.
Original notes:
- `Tools/WindowsEFI/Makefile`: build both targets (`aarch64-unknown-windows`, `x86_64-unknown-windows`; start from the
  same flags, drop `-mno-implicit-float` if clang rejects it, add `-mno-red-zone`). The sources are plain C against
  `efi.h`; re-check the GOP/`ReinstallProtocolInterface`/timer code for anything that assumed ARM (cache maintenance,
  `UINTN` width is 64-bit on both).
- Generate `WindowsEFIBinaries` with `framebufferARM64/loaderARM64` and `framebufferAMD64/loaderAMD64`; pick by guest
  architecture, not by host. Test that both decode to PE files with the right `Machine` field (`0xAA64` / `0x8664`).
- `RegisterDriverOption` (persistent `Driver####` NVRAM option) must still be needed on x64: verify that Windows creates
  its own boot entry on first start there as well.

### Phase 3 — drivers, agent, scripts
- Drivers: copy the amd64 folders (list from step 6), strip `.pdb`, keep the `viosock` INF's Winsock provider files.
- Agent: nothing to change in `Utilities.cakeagentWindowsBinary`; check `cakeagent-windows-amd64.exe` with the vsock
  listener (cakeagent PR #18) is in the snapshot `CAKEAGENT_SNAPSHOT` points at.
- `SetupComplete.cmd` has nothing architecture-specific; keep the `agent=<code>-running`/`vsock=` marker.

### Phase 4 — validation on the Intel Mac (the only part that needs it)
1. `caked build win11x64 iso:///…Win11_x64.iso --cpus 4 --memory 8192 --disk-size 64 --user admin --password admin --autoinstall --log-level=info`
2. Expect, in the log: `Windows first boot completed: done winfsp=0 service=0 share=none vsock=running agent=0-running`.
3. `caked start win11x64`, then confirm the agent over vsock with a mutual-TLS gRPC `Info` call through the VM's
   `agent` socket (see section 5; `caked exec` needs a TTY and hung during the ARM run, don't rely on it).
4. Repeat with `--mount <dir>` and check `Z:` shows the folder and Windows can write to it.
5. Second boot after Windows created its own boot entry works; a reboot from inside Windows stops the VM and a restart
   comes back.
6. Record install time, first-boot time and the answers to the section 2 unknowns here.

### Results on an Intel Mac (macOS 26.7.1, Core i9-10850K, 2026-10-21)
Phase 4 install of `Windows11_Client_x64_en-us_26300_9457.iso` with the framebuffer shim on (`usesFramebufferShim` true), no private
API (the PMU/trap setters are `#if arch(arm64)`): `caked build win11x64 iso:///… --cpus 4 --memory 8192 --disk-size 64 --user admin
--password admin --autoinstall --display-refit` finished in about 9 minutes (WinPE install ~4 min, first boot ~4 min) with the
marker `done winfsp=0 service=0 share=none vsock=running agent=0-running ssh=0-running gpu=0`, then `caked start` gave the
VM a DHCP address and an SSH login with the host key. So Windows 11 x64 does boot under Virtualization.framework on Intel
(unknown 2), needs no PMU/trap workaround (4), and virtio-vsock, the agent and OpenSSH come up (8); the amd64 driver folders and
`viofs` exist on the virtio-win ISO (6). Not settled: whether the shim is needed (3, never booted without it) and whether a guest
reboot stops the VM (5). The "cakeagent may not be running" warning of that build was a false positive of its marker check.
Phase 4b step 0: the guest's GPU is `PCI\VEN_1AF4&DEV_1050&SUBSYS_00501AF4` (same as Apple silicon, `Manufacturer: Apple Inc.`,
`Model: Apple Virtualization Generic Platform`), stock driver 100.103.104.30200, so the INF line for Apple's subsystem id applies to x64.
Step 1 (stock x64 driver, `display.ps1` copied by hand, autologon on, resized through `vmrun.Service/SetScreenSize`; with `grpcurl`
the target must be `unix:///path/to/svc`, `-unix` dials TCP here): 1280x720 shows black with garbled fragments and 800x600 horizontal
streaks, 1024x768 (the boot size) is clean. **Intel has the same corruption, so the x64 build of the patched driver is needed (step 3).**

### Phase 4b — GPU driver and display resizing on Intel (after Phase 4 passes)

State on Apple silicon (see `Tools/WindowsGPUDriver/README.md` and the CLAUDE.md Windows section): the stock `viogpudo`
re-creates its framebuffer resource with the id it just released, and Virtualization.framework shows a corrupted picture
after a resolution change (only the width the guest booted with is right). caker's build can give each framebuffer a new id,
but only when the driver value `UseFreshResourceId` is set, and the INF sets it only for the PCI subsystem id
Virtualization.framework gives its virtio GPU on Apple silicon (`PCI\VEN_1AF4&DEV_1050&SUBSYS_00501AF4`); every other device
keeps the original code (upstream: virtio-win/kvm-guest-drivers-windows#1687, two commits). The script that makes the guest follow
the host's size is only installed together with that driver. Whether VZ on **Intel** has the same problem, and which PCI
subsystem id its GPU reports, is unknown, so look before building anything:

0. **Read the Intel guest's GPU identity** (any Phase 4 guest, stock driver):
   `Get-PnpDevice -FriendlyName "*GPU*" | % { (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_HardwareIds).Data }`,
   and `Get-CimInstance Win32_ComputerSystem | Select Manufacturer,Model` (Apple silicon says `Apple Inc.` / `Apple Virtualization
   Generic Platform`). If the GPU is `…&SUBSYS_00501AF4` the existing INF line already applies on x64 (the `.inx` is shared by
   all architectures); if it differs, the INF needs a line for that id (step 3) and the upstream PR needs the same.
1. **Measure with the stock x64 driver.** On the Phase 4 install, temporarily let x64 carry the display script (relax
   the `usesCakerGPUDriver` check where `display.ps1` is written, or copy `display.ps1` into the guest by hand and add the
   `HKLM\...\Run` entry), create the VM with `--display-refit`, and ask for sizes through the VM's service socket:
   `grpcurl -cacert ~/.cake/agent/ca.pem -cert ~/.cake/agent/client.pem -key ~/.cake/agent/client.key -import-path Sources/cakedlib/VMRunService/GRPC -proto mount.proto -d '{"width":1280,"height":720}' -unix ~/.cake/vms/<vm>.cakedvm/svc vmrun.Service/SetScreenSize`
   (try 1280x720, 800x600, 1920x1080, 1100x700, then 1024x768). Look at `~/.cake/vms/<vm>.cakedvm/screenshot.png` after ~9 s:
   a clean desktop at each size means Intel doesn't need the patched driver; black with garbled fragments above a width
   of 1024, or horizontal streaks below it, means it does. Don't judge by the guest's own mode (it is always right) or by
   `System.Windows.Forms.Screen` in a long-lived process (it keeps the old mode).
2. **If clean**: keep the stock driver on x64, but still ship the display script there. Split the two decisions in
   `WindowsArchitecture` (`usesCakerGPUDriver` stays false for `.amd64`; add a `followsDisplaySize` that is true for both)
   and gate `display.ps1` on the new value. Record the result here and as a comment on #1687 (the option is already off for
   anything that isn't Apple silicon, so nothing there changes).
3. **If corrupted**: build the x64 driver and ship it like the ARM64 one.
   - Build on any Windows 11 machine with Visual Studio Build Tools (MSVC x64 and ARM64 + Spectre libraries), the Windows
     SDK/WDK 10.0.26100 and the WDK's MSBuild toolset (`WDK.vsix` rejects Build Tools: unzip it and copy
     `$MSBuild\Microsoft\VC\v170` over the Build Tools'). The ARM64 build VM (`caked build`, then install the tools over
     `caked exec`/SSH) has the x64 compiler too and should be able to cross-build x64 (not tried); on the Intel Mac a
     Windows x64 VM does it natively.
   - Source: the fork branch `Fred78290/kvm-guest-drivers-windows` `viogpu-fresh-framebuffer-resource-id` (or upstream
     `master` once #1687 is merged). If step 0 found another subsystem id, first add a model line for it to
     `viogpu/viogpudo/viogpudo.inx` next to the `SUBSYS_00501AF4` one (same install section: `VioGpuDod_Apple_Inst`, which adds
     `UseFreshResourceId=1`), push it to the PR and say so there. Build `VirtIO\VirtioLib.vcxproj` then
     `viogpu\viogpudo\viogpudo.vcxproj` with `/p:Configuration="Win11 Release" /p:Platform=x64`; the output should be
     `viogpudo\objfre_win11_amd64\amd64\viogpudo\` by analogy with the ARM64 folder (the packaging errors about
     `viogpuap`/`viogpusc`/`viogpures` are harmless).
   - Sign `viogpudo.sys` and `viogpudo.cat` with a **new** self-signed code-signing certificate
     (`New-SelfSignedCertificate -Type CodeSigningCert`, `signtool sign /fd SHA256 /sha1 <thumbprint> /sm`); the ARM64
     certificate's private key was deleted on purpose, so either ship a second `.cer` or re-sign both architectures with
     one new certificate (rebuild the ARM64 files too). Export only the `.cer` and delete the private key afterwards
     (`RSACng.Key.Delete()` on the certificate's private key, then remove it from the store).
   - Put `viogpudo.sys/.inf/.cat` and the `.cer` in `Tools/WindowsGPUDriver/amd64/`, extend `embed.sh` to emit both
     architectures, make `WindowsGPUDriverBinaries` per architecture (`sys(for:)` … or nested enums), return true from
     `usesCakerGPUDriver` for `.amd64`, and update `WindowsInstallationMedia.populate` (it writes the ARM64 files today) and
     the README hashes. Tests: PE `Machine` is `0x8664` for the x64 `.sys` (the ARM64 test checks `0xAA64`), and the x64 INF
     has the Apple/Intel line and `UseFreshResourceId` (the ARM64 test already checks both).
   - Nothing else changes: `install.cmd` already adds drivers with `dism /ForceUnsigned` when `usesCakerGPUDriver` is
     true, and `SetupComplete.cmd` trusts the certificate, runs `bcdedit /set testsigning on` and reports `gpudriver=<code>`.
4. **Verify on Intel** (fresh install, nothing overridden): marker `… gpudriver=0 display=0` and no warnings; after the second
   start `Win32_PnPSignedDriver` shows the caker build (version `100.6.…`), the device status is OK, `bcdedit` says
   `testsigning Yes`, `DEVPKEY_Device_MatchingDeviceId` is the INF line you expect, and the driver key
   (`HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000`, where the INF's `HKR` entries
   land; **not** the device's `Device Parameters`) has `UseFreshResourceId=1`. Then the host-side resize check from step 1 is
   clean at every size. For a quick A/B on the same VM, delete that value (or set it to 0), shut the guest down and start it
   again: the picture must be corrupted like the stock driver's, which proves the option and not something else made the
   difference.
5. Update `wiki/provisioning.md` (EN/FR, "Display resizing"), the CLAUDE.md Windows section, the PR description and, if the
   result is useful upstream, a comment on virtio-win/kvm-guest-drivers-windows#1687.

Things learned on the ARM run that save time:
- Never swap the GPU driver in a running guest (`pnputil /restart-device`, deleting the package, `UpdateDriverForPlugAndPlayDevices`
  all hard-stop the VM or roll back; the WHQL-signed stock package also outranks a test-signed one). Replace it on the
  media, as the installer does. To try a different build in an existing test VM without a new install, copy the signed `.sys`
  to `System32\drivers\<new name>.sys`, point the `VioGpuDod` service's `ImagePath` at it and shut the guest down cleanly.
- A guest that sits idle goes to sleep and its agent stops answering (`caked exec` hangs): `powercfg /change standby-timeout-ac 0`
  and `monitor-timeout-ac 0`. Autologon only covers first boot; for a test VM set `AutoAdminLogon`/`DefaultUserName`/`DefaultPassword`
  under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`, and a script in a Run entry that polls for a command
  file is an easy way to run things in the logged-on session (scheduled tasks created from `caked exec` never fired).
- A debug `caked` built with plain `swift build` loses its signature: re-sign it ad hoc with only
  `com.apple.security.virtualization` (adding `com.apple.vm.networking` makes the system kill it).
- Two `vmrun` processes for one VM (a leftover from a killed run) make the second fail with "EFI variable store is already in use": `pkill -9 -f "vmrun.*<vm>"`
  and remove `run.pid`/`svc` from the VM folder before starting.
- Killing a `caked build` of a Windows VM leaves the ISO and `install.winmedia` attached, and the next build fails with
  `hdiutil: attach failed - Resource busy`: `hdiutil info -plist`, then `hdiutil detach -force /dev/diskN` for those two images only.
- If the working tree doesn't build for an unrelated reason, `git worktree add --detach ../caker-test HEAD`, copy the changed
  files in and build there (about a minute and a half with warm caches); remove it with `git worktree remove --force` afterwards.

### Phase 5 — docs and release hygiene
- `wiki/provisioning.md` (EN/FR): Intel support, ISO architecture rules, limits; regenerate `docs/` with
  `GITHUB_REPOSITORY=Fred78290/caker ./Scripts/sync-docs-from-wiki.sh`.
- `CLAUDE.md` Windows section: replace "Intel Macs (the helpers are AArch64)" with the real state; note the host/guest architecture rule.
- If new Swift files are added, register them in both `.pbxproj` files (see "Keeping Xcode projects in sync").
- PR description: lead with what was verified on Intel and what was not (other CPUs, non-English ISOs).

## 4. Risks and fallbacks
- **Windows x64 doesn't boot under VZ on Intel** (step 2): document "not supported on Intel", keep the `WindowsArchitecture`
  refactor only if it simplifies the ARM code, otherwise don't merge it.
- **Toolchain can't run on Intel**: develop on Apple silicon, cross-build x86_64, test on the Intel Mac (step 1).
- **Shim needed but the x64 build misbehaves**: debug with `make DEBUG=1` (on-screen bring-up markers) and a VNC
  screenshot loop; the framebuffer driver is small (≈400 lines) and has no ARM-specific code beyond the target triple.
- **Intel Macs lose macOS support after 26**: don't use macOS 27-only API in anything the Windows path touches.

## 5. Running this plan with Claude desktop on the Intel Mac

Prerequisites on the Intel Mac:
- Claude desktop (Code tab) signed in, this repository cloned, `gh` authenticated, a branch such as `feat/win11-intel` created from `feat/win11-extras`.
- Xcode command line tools and the newest Xcode that runs there; `brew install lld llvm openssl@3 go` (go only to build the cakeagent probe).
- A Windows 11 **x64** English ISO (e.g. `Win11_25H2_English_x64.iso`), the virtio-win ISO (downloaded automatically, ~880 MB), network access to GitHub releases.
- `caked` must carry the virtualization entitlement (a plain `swift build` binary doesn't): use `./Scripts/build-signed-debug.sh`
  or `xcodebuild -project Caker/Caker.xcodeproj -scheme Caker -configuration Debug build` and run the `caked` inside the built `Caker.app/Contents/PlugIns/caked.app`.

Kickoff prompt to paste into a Claude desktop session opened on this repo:

> Read `WINDOWS_INTEL_PLAN.md` and `CLAUDE.md` (Windows sections). We are on an Intel Mac. Start with section 2: settle the
> unknowns in order, one spike at a time, and write each answer into the plan before moving on. Stop and ask me at the gate
> after unknowns 1 and 2 and again after 3. Then do phases 1, 3, 2 (if needed), 4, 5, committing after each phase and running
> `swift test` before every commit. Never push without asking.

Practical notes for the session (all learned on the ARM run):
- Nothing is shown while WinPE runs, so the only feedback channels are the first-boot marker (`caker\result`,
  `install.log` on the media; `EFI\caker\installed` on the system disk's ESP) and, once Windows is up, the agent. If the
  agent isn't running, `SetupComplete.cmd` runs it in front for 8 s and the host logs `cakeagent output:` from `EFI\caker\agent.log`.
- A VNC screenshot helper (RFB client with DES via Homebrew `openssl` legacy provider) was used to look at the guest;
  it lives outside the repository. Typed keys go through the *host* keyboard layout, so on a non-US Mac remap
  letters (an AZERTY host needs `qd,in` to type `admin`); keys need ~60 ms hold time. Porting it to `Scripts/` is a
  sensible small task for this session.
- Agent check without `caked exec`: a small Go program using `cakeagent.NewCakeAgentServiceClient` with the host's
  client certificate from `~/.cake/agent`, dialing the VM's `agent` unix socket, calling `Info`. A good run prints
  `OS=windows host=<name> cpu=<n> mem=<n> MiB`.
- Test VMs are large (64 GB sparse, plus the 8 GB install media while building): delete them with `caked delete <name>` when done.
- Build time on the ARM run was ~8 minutes end to end; budget a similar time per install attempt on Intel, and prefer
  changing one thing per attempt.

## 6. Acceptance criteria
- Phase 1 merged with ARM behaviour unchanged (existing Windows tests green, a real ARM install still reports `agent=0-running`).
- On an Intel Mac: the section 4.1–4.5 checks pass with a Windows 11 x64 ISO, or this file records which unknown made it impossible.
- Phase 4b: the GPU's PCI subsystem id on Intel is recorded here, and the resize check is clean at every size with the stock driver or with an x64 build of caker's (whose INF turns `UseFreshResourceId` on for that id only); the choice is recorded here.
- `swift build --arch x86_64` and the full `swift test` pass; docs and French strings updated.
