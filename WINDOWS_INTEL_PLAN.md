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

### Phase 2 — x64 EFI helpers (only if step 3 says they are needed)
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
- `swift build --arch x86_64` and the full `swift test` pass; docs and French strings updated.
