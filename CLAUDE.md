# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Caker?

Caker is a macOS-only toolchain for building and managing virtual machines using Apple's Virtualization framework (requires macOS 15+). It consists of four main executables and a shared library, all defined as Swift Package Manager targets in `Package.swift`.

## Build Commands

```bash
# Basic Swift package build (CLI tools only)
swift build -Xswiftc -D -Xswiftc SPARKLE

# Run all Swift package tests
swift test

# Run a single test class
swift test --filter CakerTests.<TestClassName>

# Signed debug build (requires certificates)
./Scripts/build-signed-debug.sh

# Signed release build
./Scripts/build-signed-release.sh
```

**Web UI** (`webui/`, requires Node.js ≥ 18):
```bash
cd webui && npm install
npm run dev          # Vite dev server on :5173 proxying /1.0 to caked
npm run build        # Production build to webui/dist/
```

**Integration tests** (`integration/tests/`, Python pytest):
```bash
pip install -r integration/tests/requirements.txt
pytest integration/tests/
```

## Architecture

### Component Map

| Target | Source | Role |
|---|---|---|
| `caked` | `Sources/caked/` | Core daemon: gRPC server, optional LXD REST API, launchd service |
| `cakectl` | `Sources/cakectl/` | CLI client — talks to caked over gRPC |
| `caker` (Caker.app) | `Sources/caker/` | macOS SwiftUI desktop app, embedded VM runner |
| `CakedLib` | `Sources/cakedlib/` | Shared core: VM logic, networking, OCI, Cloud-Init, importers |
| `GRPCLib` | `Sources/Grpc/` | gRPC contract + generated client/server code |
| `VirtualInstallSPI` | `Sources/VirtualInstallSPI/` | C shim exposing private `MobileDevice`/`Virtualization` SPIs, used by `CakedLib` |

### Communication Flow

```
cakectl ──gRPC──► caked (gRPC server)
                     │
LXD/lxc ──REST──►   │  (--rest flag: Vapor HTTP/HTTPS on :8080/:8443)
                     │
webui ──REST──►      │  (served at /ui by caked's Vapor server)
                     │
Caker.app ──gRPC──►  │  (also uses GrandCentralDispatcher stream for live status)
                     │
                  VMRunService ──► VMs (gRPC or XPC per-VM backend)
```

When `caked` is running as a service, operations should go through `cakectl` rather than direct `caked` command invocation.

### Key Subsystems in CakedLib

- **`VMRunService/`** — Two backends for per-VM process management: `GRPC/` (network-based) and `XPC/` (inter-process). Each running VM spawns its own service.
- **`OCI/`** — OCI container image management (pull, push, purge, store).
- **`CloudImage/`** — Cloud image support: `CloudInit.swift`, `SimpleStreams.swift` (Ubuntu streams), `ImageCache.swift`.
- **`Importers/`** — Import VMs from Multipass or VMware.
- **`VNCLib/`** — VNC tunnel support (via RoyalVNCKit).
- **`VMNet/`** — Virtual network management (bridged, hosted, NAT modes).
- **`CakerEnv.swift`** — `.cakerenv` YAML format describing multi-VM environments with dependency ordering.
- **`Config.swift`** — `CakeConfig` backed by `config.json` and `cake.json` files per VM.
- **`PackerLite/`** — drives a freshly-installed VM's unattended first-boot setup (macOS Setup Assistant from an IPSW, or a Linux first-boot installer from an ISO): `PackerLiteDriver.swift` replays a parsed `boot_command` via its own in-process `CGEvent`/`NSEvent` synthesis and Vision OCR, `PackerLiteEngine.swift` owns the boot/provision/shutdown lifecycle, `PackerLiteTemplateResolver.swift` picks a template, and `PackerLiteTemplate.swift`/`BootCommand.swift`/`MacOSVersion.swift` hold the parsing/model types — all part of `CakedLib` itself (no separate SPM target). See [Architecture: PackerLite](#packerlite-unattended-os-provisioning) below.

### gRPC Contract

The single source of truth is `Sources/Grpc/service.proto`. The generated files `service.grpc.swift` and `service.pb.swift` **must not be edited manually** — regenerate them with:

```bash
cd Sources/Grpc && ./generate.sh
```

This script clones `grpc-swift`, builds the protoc plugins, then runs `protoc`. The `VMRunService` has its own separate proto at `Sources/cakedlib/VMRunService/GRPC/mount.proto`.

### LXD REST API

Enabled with `caked service listen --rest`. The Vapor-based server is in `Sources/caked/REST/`:
- `LXDRESTServer.swift` + `Routes.swift` — server setup and route registration
- `Controllers/` — one controller per LXD endpoint group (instances, networks, images, etc.)
- `LXDModels.swift` — Codable types mirroring the LXD REST API
- `LXDOperationStore.swift` — async operation tracking

The TypeScript counterpart lives in `webui/src/types/lxd.ts`.

### GrandCentral Pattern

Caker.app subscribes to the `GrandCentralDispatcher` gRPC streaming call to receive live VM status (CPU, memory, screenshots, state changes). Each running VM calls `GrandCentralUpdate` to push its status to `caked`, which then fans out to connected GUI clients. This is how the desktop app stays in sync without polling.

### SwiftUI front-app activation from a terminal launch

`caked`'s GUI paths (`MainApp.swift`, used by `caker` and by `caked provision --foreground`) are sometimes launched via fork/exec from a terminal or shell script rather than through Finder/LaunchServices. macOS does not automatically grant a process launched that way frontmost/active status, and SwiftUI's `App`/`WindowGroup` scene lifecycle alone doesn't compensate — the window can open fully behind other apps with no visible cue that it exists. `AppDelegate` works around this with a plain `NSWindow` splash screen (not a SwiftUI `Window`/`WindowGroup` scene) shown at `.floating` level via `NSHostingView`, plus three layered activation attempts (`NSApp.activate(ignoringOtherApps:)` in `Extensions.swift`'s `setDockIcon()`, the splash window's own `.floating` level, and a 2s-delayed `NSApp.activate()` fallback — originally 5s, tightened once the pattern proved reliable), transitioning to the real `WindowGroup` via `EnvironmentValues().openWindow(id:)` once `applicationDidBecomeActive` actually fires. **`SplashScreenView` and its `showSplashWindow(name:)` factory now live in `Sources/cakedlib/UI/SplashScreenView.swift`** (moved out of `caked`'s own `MainApp.swift`), specifically so `Sources/cakedlib/UI/VNC/VNCApp.swift` — the standalone VNC client window `cakectl provision` launches inline (see PackerLite section below) — can reuse the exact same splash-then-activate workaround via its own `AppDelegate.applicationWillFinishLaunching`, rather than duplicating it. See the "Front-app activation workaround" comment block above `caked`'s `AppDelegate` in `Sources/caked/MainApp.swift` for the full explanation of why each layer exists — `VNCApp`'s copy is intentionally lighter (calls `SplashScreenView.showSplashWindow` directly) since the underlying rationale is identical.

### PackerLite (unattended OS provisioning)

PackerLite drives a VM's unattended first-boot setup after `VMBuilder.swift` finishes installing it — macOS Setup Assistant for `.ipsw` builds, or a Linux first-boot/OEM installer for `.iso` builds — via a parsed `boot_command`, the same concept as HashiCorp Packer's `boot_command` / `packer-plugin-tart`, built natively with no external binary or plugin. It only runs when `--autoinstall` is passed to `build`/`create`; there's no automatic provisioning otherwise. The two source types resolve their template very differently:

- **IPSW (macOS)**: `PackerLiteTemplateResolver.resolve(...)` (`Sources/cakedlib/PackerLite/PackerLiteTemplateResolver.swift`) picks the template in this order, throwing if none apply: explicit `--template <path>` → macOS version auto-detected from the IPSW filename (`MacOSVersion.detect(fromIPSWFilename:)`, Apple's `UniversalMac_<version>_<build>_Restore.ipsw` convention, which also yields the dotted version string, e.g. "15.6") → explicit `--macos-version` → failure. Built-in templates are bundled as `CakedLib` SPM resources at `Sources/cakedlib/PackerLite/Resources/vanilla-*.packerlite.yaml`, one per version: `macos12`, `macos13`, `macos14`, `macos15`, `macos26`, `macos27` — all six now ship a template, including `macos27` (added alongside the rename below; it was the last gap). **`MacOSVersion`'s raw values were renamed from marketing names to numeric identifiers** (`monterey`→`macos12`, `ventura`→`macos13`, `sonoma`→`macos14`, `sequoia`→`macos15`, `tahoe`→`macos26`, `goldengate`→`macos27`) — the enum itself, `bundledTemplateResourceName`, the bundled `.packerlite.yaml` filenames, and the proto's `Caked_MacOSVersion` cases all moved together. Old marketing names still work as `--macos-version` input: `GRPCLib.MacOSVersion.init?(argument:)` (`Sources/Grpc/options/BuildOptions.swift`) checks a `formerNames: [String: MacOSVersion]` lookup before falling back to `init(rawValue:)`, so existing scripts/docs using `tahoe` etc. keep working — but `MacOSVersion.allCases`/`.rawValue` (used for `--help` text, `CakeConfig.osName` storage, and template filenames) only ever produce the numeric form now. The detected codename/version are persisted unconditionally into `CakeConfig.osName`/`osRelease` (regardless of `--autoinstall`), so a later standalone `caked provision` run knows what the VM is without the original IPSW.
- **ISO (Linux)**: `PackerLiteTemplateResolver.resolveLinuxTemplate(...)` mirrors the macOS resolver but keyed on distro instead of version: explicit `--template <path>` → distro auto-detected from the ISO filename/URL via `GRPCLib.SupportedPlatform(rawValue:)` → bundled default for that platform, if one exists (`Sources/cakedlib/PackerLite/Resources/linux-{fedora,centos,redhat,opensuse,debian}.packerlite.yaml`) → otherwise `nil` (not an error) — the expected outcome for Ubuntu (its own cloud-init/subiquity path handles autoinstall) or any distro caker doesn't recognize. `VMBuilder` only runs PackerLite for an ISO build when `--autoinstall` is set and this resolves to non-nil content. None of the five Linux templates have been validated against a real boot, unlike the macOS ones. `caker`'s VM creation wizard (`Sources/caker/Views/VirtualMachineWizard.swift`) surfaces an optional YAML file picker for non-Ubuntu ISO sources — required only when `PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for:)` is false for the detected platform.

**`SupportedPlatform(rawValue:)` bug fixed alongside this**: the substring match used to compare a lowercased input against un-lowercased case raw values, so `.openSUSE` (raw value `"openSUSE"`, mixed case) could never match — including reading back a value the type itself had written via `CakeConfig.configuredPlatform`'s setter. Also added `"rhel"` as an alias for `.redhat`, since official RHEL ISO filenames use that, not `"redhat"`. See `Sources/grpc/VirtualMachineConfiguration.swift`.

In both cases the VM's account always comes from `CakeConfig.configuredUser`/`configuredPassword` (`--user`/`--password`), injected into the template as `${var.username}`/`${var.password}` — templates must not declare their own.

**`PackerLiteEngine`** (`Sources/cakedlib/PackerLite/PackerLiteEngine.swift`) now has three entry points, plus a private step-runner shared by all of them:
- A public `provision(vm:targetView:commands:resolvedBootTimeout:progressHandler:)` just replays one already-parsed `BootCommandSteps` sequence against a target `NSView` under a `resolvedBootTimeout` watchdog — no template/IP/agent logic, purely "run these steps." (`ProvisionHandler` also calls this directly for the `pre_boot_command` phase — see below — so it can no longer be `private`.)
- `provision(vm:template:runningIP:runMode:progressHandler:)` drives an already-running `VirtualMachine`'s **`boot_command`** phase (`template.bootCommand`, already parsed — see `ParsedPackerLiteTemplate` below — handed straight to the step-runner above), then — once an IP is available — installs the cakeagent and sets `config.agent = true`. Used by `CakedLib.ProvisionHandler` (`Sources/cakedlib/Handlers/ProvisionHandler.swift`), the shared standalone-provisioning entry point both `caked provision` and the `Provision` gRPC RPC delegate to, which boots the VM itself (with a UI window locally, headlessly-but-with-VNC over gRPC) instead of assuming a caller already booted it.
- `provision(id:location:config:template:runMode:progressHandler:)` is the build-time orchestrator — called from `Sources/cakedlib/Handlers/BuildHandler.swift` as an explicit **post-build** step (after the VM is relocated from its temp directory to its permanent location), not inline inside `VMBuilder.swift` anymore (`VMBuilder` no longer contains any provisioning logic at all). It owns the **full two-stage pipeline**: it starts the VM itself (`vm.startVM()`), runs an optional **`pre_boot_command`** phase immediately — before any IP is available — then waits for an IP via `location.waitIPWithLease(config:wait:runMode:)` and hands off to the `runningIP`-based overload above for the main `boot_command` phase + agent install. `id: UUID` is the build session's identifier (see "Stable build-session UUID" below) — this overload also tracks the in-flight `VirtualMachine` in `PackerLiteEngine.provisioned: [UUID: VirtualMachine]` and posts `provisionedStartNotification`/`provisionedTerminatedNotification` (keyed by that UUID in `userInfo["wizardID"]`) when running inside `caker` (`Bundle.runInCaker`), so the VM creation wizard can show the live VM view inline during provisioning instead of only in a separate debug window (see `Sources/caker/Views/VirtualMachineWizard.swift`, `PackerLiteEngine.provisionedStartNotification`/`.provisionedTerminatedNotification` handlers).

**`ParsedPackerLiteTemplate` now separates parsing from the raw template model.** `PackerLiteTemplate` (`Sources/cakedlib/PackerLite/PackerLiteTemplate.swift`) is a `Codable` decode-only DTO whose fields (`variables`, `bootTimeout`, `preBootCommand: [Command]?`, `bootCommand: [Command]?`) are all `private` now — nothing outside the file touches them directly. `@MainActor public static func load(from:variables:) throws -> ParsedPackerLiteTemplate` (and a `fromFile:` overload, `async`, since it also does file I/O) decodes the YAML, substitutes `${var.*}`, and fully parses `boot_command`/`pre_boot_command` in one call, returning `ParsedPackerLiteTemplate` — a small `Sendable` struct with `bootTimeout: TimeInterval` (already resolved, not a string) and `preBootCommand`/`bootCommand: BootCommandSteps` (already-parsed `[BootCommandStep]`, not raw `[Command]`). Callers (`PackerLiteEngine`, `ProvisionHandler`) work with this parsed value directly — there's no more separate `parsedBootCommand()`/`resolvedBootTimeout` step to call. **This also removed `async` from the whole boot-command parsing path** (`BootCommand.parse`, `BootCommandStep.init`) — the earlier `TISInputSource`-driven keyboard-layout lookups that required it are now wrapped in the `@MainActor`-isolated `load`/`parse` instead, so `PackerLiteTemplate.load` can be called synchronously (well, via one `@MainActor` hop) from inside `VMRunHandler`'s run closure rather than needing a detached `Task`.

`pre_boot_command:` (`PackerLiteTemplate.preBootCommand`, parsed the same way as `bootCommand`) exists specifically for Linux ISO installs: some distros' GRUB boot menus need early keystrokes (navigate + Enter) sent before the installer has come up far enough to have an IP — previously this was covered by a blind wait before the main `boot_command` phase even started; several bundled Linux templates (`linux-{centos,debian,fedora,opensuse,redhat}.packerlite.yaml`) now use `pre_boot_command` for that GRUB-navigation step instead, cutting the blind wait from ~30s down to 5s. macOS templates have no use for `pre_boot_command` — Setup Assistant only ever starts after the OS is already up.

Both `PackerLiteEngine.provision` entry points that reach the runningIP-based overload mark `CakeConfig.provisioned = true` on success via the shared driving path.

**Standalone provisioning is now available three ways**, all converging on `CakedLib.ProvisionHandler.provision(...)`:
- `caked provision <vm>` (`Sources/caked/Commands/Provision.swift`) — local-only, boots the VM with a visible window via `VMRunHandler` so the operator on that host can watch.
- `cakectl provision <vm>` (`Sources/cakectl/Commands/Provision.swift`) — the gRPC client, added alongside a new server-streaming `Provision` RPC (`Sources/Grpc/service.proto`: `ProvisionRequest`/`ProvisionStreamReply`/`ProvisionedReply`, mirroring `Build`'s streaming pattern) so provisioning can be driven remotely, same as `build`/`launch`. **Must be registered in `Client.swift`'s `subcommands:` array** (`Sources/cakectl/Client.swift`) like every other cakectl command — this was initially missed when the command file was added, leaving `cakectl provision` invisible to ArgumentParser despite the file, the proto RPC, and the server handler all being wired up; worth double-checking after adding *any* new cakectl command, since a missing registration compiles cleanly and fails silently (the command just doesn't appear in `--help` or parse).
- The `Provision` RPC's server-side handler is `Sources/caked/Handlers/ProvisionHandler.swift` (`ProvisionHandler: CakedCommandAsync`, dispatched from `CakedProvider.provision(request:responseStream:context:)`), which streams `.progress`/`.step`/`.substep`/`.terminated` back to the client exactly like the `Build` RPC does, ending in a `ProvisionedReply`.

**`cakectl provision` now opens a live VNC window inline**, instead of just printing progress until completion. `CakedLib.ProvisionHandler` starts the VM's VNC server as soon as it's up and sends a new `.infos(ProvisionInfo)` progress event (`ProvisionInfo`: VNC URL, screen size, `CakeConfig`) over the stream — `ProvisionStreamReply.ProvisionInfo` (field 6 in `Sources/Grpc/service.proto`). `cakectl`'s `Provision` command (`Sources/cakectl/Commands/Provision.swift`) changed from `AsyncGrpcParsableCommand` to `GrpcParsableCommand` specifically to support this: its synchronous `run(client:arguments:callOptions:)` wraps the whole async streaming loop in `withCheckedThrowingContinuation`, resuming as soon as an `.infos` event arrives (via a `Synchronization.Mutex`-guarded `resume(_:)` helper, since both the stream-reader task and a clean-completion path can race to resume it) rather than waiting for the stream to fully finish. Once resumed with `ProvisionInfo`, it opens an SSH-tunneled VNC session through `VNCApp.startVncClient(...)` (`Sources/cakedlib/UI/VNC/VNCApp.swift`) — the same `VNCApp` used elsewhere for post-build VNC viewing — reusing the shared `SplashScreenView` splash-then-activate workaround described above while it connects. Progress/step/substep events continue streaming and printing in the background for the remainder of the run.

Template `boot_command` entries are `{title, command}` objects (not bare strings) — the `title` surfaces as a progress substep and in logs. `BootCommand.swift`'s token vocabulary covers waits, text/press/click, `<leftShiftOn>`/`<leftShiftOff>`-style modifier holds (including `<fnOn>`/`<fnOff>`), `F1`–`F20`, `<click 'On-screen text'>` (Vision OCR), and `<keyboard 'source-id'>` to switch the active TIS keyboard-layout translator at runtime (`'current'` captures whatever layout is active on the host). `PackerLiteDriver` synthesizes `CGEvent`/`NSEvent`s directly against the VM's rendered `NSView` — it no longer wraps `VNCInputHandler`, just reuses the same synthesis technique in-process. `parseAttributes(_:token:)` (shared by the `click`/`locate`/`skipNotFound`/`scroll` attribute-style tokens) now takes an explicit `token` name and throws a dedicated `.malformedAttribute` case instead of always throwing `.malformedClick` regardless of which token actually failed to parse — a leftover from `click` being the first attribute-style token added, before the others copied its parsing without generalizing the error too. A separate misclassified `.malformedClick` throw in the keyboard-parsing path was also corrected to `.malformedKeyboard`.

`caker`'s VM creation wizard (`Sources/caker/Views/VirtualMachineWizard.swift`) now shows the running VM's live view **inline** — a real embedded VNC connection, not just the raw `VZVirtualMachineView` — in the wizard's own content area while PackerLite provisioning is in progress, instead of requiring a separate debug window. This rides on `PackerLiteEngine.provisioned: [UUID: VirtualMachine]` plus `provisionedStartNotification`/`provisionedTerminatedNotification` (see above): the wizard tracks its own session via a `UUID` `wizardID` (promoted from `String` to match `BuildOptions.identifier`'s type) and matches it against each notification's `userInfo["wizardID"]`. The old separate debug-window path still exists but only under a `DEBUG_PAKERLITE` build flag. The wizard's various VM-related `DispatchQueue`s were also consolidated into one `static let wizardQueue` on `VirtualMachineWizard`. (The VM view's rounded-corner container/clipping mentioned in earlier revisions of this doc was later removed — it didn't suit the VNC-embedded view's own chrome.)

Everything under `Sources/cakedlib/PackerLite/` (driver, engine, resolver, template/`boot_command` parsing, and the resource-bundled `.packerlite.yaml` templates) is part of `CakedLib` itself — there is deliberately **no separate `PackerLite` SPM target**. There was one originally, split out for unit-testability, but it forced `GRPCLib` to depend on it too (for the `--macos-version` CLI option's type), and `CakedLib` already depends on `GRPCLib` — so keeping a shared leaf target meant mirroring an entire extra native target in both Xcode projects (see below) just to avoid one small enum duplication (since resolved a different way — see next). It was folded back into `CakedLib`.

**`MacOSVersion` is no longer duplicated** (it used to be — `GRPCLib` and `CakedLib` each had their own enum, bridged by raw value at the few call sites that needed both). It's now declared **once**, in `GRPCLib` (`Sources/grpc/options/BuildOptions.swift`, still `ExpressibleByArgument` for the CLI), with `CakedLib` adding its template-selection behavior via `extension MacOSVersion { ... }` (`Sources/cakedlib/PackerLite/MacOSVersion.swift`: `bundledTemplateResourceName`, `init?(major:)`, `detect(fromIPSWFilename:)`) rather than declaring a second competing type. `GRPCLib` also gained `MacOSVersion.init?(_ from: Caked_MacOSVersion) throws`, bridging directly from the proto's own `ProvisionRequest.MacOSVersion` enum — needed once provisioning went over gRPC and the wire format needed a `MacOSVersion` too. Since there's only one type now, plain `MacOSVersion` is unambiguous everywhere, including in a file that imports both `GRPCLib` and `CakedLib` — the `GRPCLib.MacOSVersion`/`CakedLib.MacOSVersion` qualification dance from before is gone. (Note: `BuildOptions.swift`'s doc comment above the enum still describes the old two-enum arrangement — it wasn't updated when the duplication was removed, so don't trust it over the code.)

**Stable build-session UUID**: `BuildOptions.identifier: UUID` (`Sources/Grpc/options/BuildOptions.swift`) is generated once per build session and threaded through `VMLocation.tempDirectory(_:runMode:)`, `VMBuilder.buildVM(_:vmName:...)`, and `PackerLiteEngine.provision(id:location:config:template:runMode:progressHandler:)` — so the temp directory name and the provisioning session's `provisioned`/notification tracking (see above) share one caller-controlled identifier instead of each generating its own random UUID independently. `Sources/cakedlib/Handlers/BuildHandler.swift` is the source of that identifier for a real build (`options.identifier`, passed to both `VMLocation.tempDirectory` and `VMBuilder.buildVM`).

**Misc PackerLite/VM-lifecycle fixes worth knowing about**: `VMLocation.waitIPWithLease(config:wait:runMode:startedProcess:)` now takes an already-resolved `CakeConfig` from the caller instead of calling `self.config()` internally — every call site already had one in hand, so this just drops a redundant (and throwing) lookup. `VirtualMachine.swift` gained `async`/`await` overloads of `startVM`/`stopVM` (built on `withCheckedThrowingContinuation`, dispatched onto `vmQueue`) alongside the pre-existing callback-based versions — `PackerLiteEngine`'s build-time orchestrator uses these. The VNC delegate's framebuffer-autoresizing setup, previously gated on `display == .vnc` only, now also covers `display == .none`, so the VM view renders correctly in caker's default/headless display configuration too. `BuildHandler.build(...)` adds a 200ms `Task.sleep` right before invoking the post-build provisioning step, as a settling period to reduce a race between the relocated VM's saved config and Setup Assistant automation starting. Agent installation now logs to `~/install-agent.log` (was `/tmp/install-agent.log`) and ends with a double `sync` call, to reduce the chance of losing writes if the VM is halted right after.

**`Bundle.module` gotcha**: `PackerLiteTemplateResolver.swift` reads bundled resources, but `Bundle.module` is only generated by real `swift build`/`swift test` (SPM's per-target codegen). The two hand-mirrored Xcode projects (see below) compile the same file as a plain native target with no such accessor, so the lookup is wrapped in `#if SWIFT_PACKAGE ... #else ...` — keep that structure if you touch resource loading here.

**Keeping `Caker.xcodeproj`/`CakerAppStore.xcodeproj` in sync**: both projects under `Caker/` hand-duplicate the SPM target graph as native Xcode targets (their own `PBXNativeTarget` per SPM library target, their own file lists, their own `Frameworks` build-phase linkage) rather than consuming `Package.swift` directly — CI/release scripts never touch them (`Scripts/build-signed-*.sh` and the release workflows all use plain `swift build`), but a human opening Xcode does. Since `PackerLite`'s files live inside the existing `CakedLib` native target, adding them there was just new `PBXFileReference`/`PBXBuildFile` entries plus a `Resources` build phase — no new target, no new `Frameworks`-phase linkage anywhere. That's the pattern to prefer: only stand up a brand-new native target (and all the dependency/linkage wiring that requires — see git history around the original `PackerLite` target for what that involved) when a genuinely new, separately-linked SPM library target is unavoidable. The two project files mostly share object UUIDs for common targets, but the App Store variant's `Caker` app target and `VirtualInstallSPI` have different UUIDs/target structure; verify with a scheme-based `xcodebuild -scheme Caker build` (not raw `-target`, which can spuriously fail on unrelated module-map resolution) before assuming a change is complete.

## Code Organization Conventions

- **Adding a command**: Mirror it in both `Sources/caked/Commands/` and `Sources/cakectl/Commands/` where applicable. Use `ArgumentParser` with `CommandConfiguration` metadata including `abstract:` and `discussion:`.
- **Shared logic**: Put it in `CakedLib` (`Sources/cakedlib/`), not in the executables.
- **gRPC changes**: Edit `service.proto`, regenerate, then update both server (`caked`) and client (`cakectl`/`caker`) sides.
- **Localization**: Use `String(localized: "...")` throughout; localization source files are in `Resources/Localizable.xcstrings`.
- **New SPM library target vs. adding files to an existing one**: a genuinely new, separately-linked target must also be mirrored as a native target in `Caker/Caker.xcodeproj` and `Caker/CakerAppStore.xcodeproj` (new `Frameworks`-phase linkage everywhere its consumers are linked) — prefer adding new files to an existing target instead when possible, since that only needs file references, not a new target; see [PackerLite (unattended OS provisioning)](#packerlite-unattended-os-provisioning) for how to validate either case with a scheme-based `xcodebuild` build.

## Code Style

Swift formatting is enforced by two configs:
- `.swift-format` — used by `swift-format` tool (tabs, 250-char line length, ordered imports)
- `.swiftformat` — used by SwiftFormat (4-space indent width, `--enable indent` only)

Indentation is **tabs** (displayed as 4 spaces). The project uses Swift language mode `.v5` (declared in `Package.swift`).

## CI / Workflows

CI workflows run only on `push` and `workflow_dispatch` events — **never on `pull_request`**. Do not add `pull_request` triggers. Each workflow includes a guard:

```yaml
if: ${{ github.event_name != 'pull_request' && github.event_name != 'pull_request_target' }}
```

Workflows: `release.yaml` (GitHub release + DMG), `appstore-release.yaml` (App Store submission), `publish-wiki.yaml` (wiki → GitHub Pages sync), `sync-docs-from-wiki.yaml` (wiki → `docs/` Jekyll site → GitHub Pages).

## Documentation / Wiki

Wiki source lives in `wiki/` — edit this, not `docs/`. Publish manually:
```bash
GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh <owner> <repo>
```

On push to `main`, `publish-wiki.yaml` syncs `wiki/` to the GitHub wiki, and `sync-docs-from-wiki.yaml` regenerates the Jekyll site under `docs/` (published at `caker.aldunelabs.com`) from it. `docs/` is generated output — changes there are overwritten by the sync.

## Tests

| Location | Type |
|---|---|
| `Tests/CakerTests/` | Swift Package Manager unit/integration tests |
| `Caker/CakerTests/` | Xcode project tests |
| `integration/tests/` | Python pytest integration tests (uses testcontainers, paramiko, scp) |
| `Caker-Package.xctestplan` | Xcode test plan for Swift package tests |

## Key External Dependencies

Most packages are **Fred78290 forks** of upstream libraries (check `Package.swift` for exact revisions):
- `cakeagent` — in-guest agent installed into managed VMs
- `containerization` — Apple containerization library (OCI, EXT4, archiving)
- `royalvnc` — VNC client (RoyalVNCKit, used as static lib)
- `grpc-swift` 1.27.2 — gRPC server and client
- `vapor` 4.x — HTTP server for the LXD REST API
- `swift-nio` family — NIO networking stack (HTTP/1, HTTP/2, SSH, SSL, port forwarding)
- `swift-argument-parser` — CLI argument parsing
- `Sparkle` 2.x — macOS auto-update (Caker.app)
