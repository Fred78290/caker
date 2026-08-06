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

### PackerLite (unattended OS provisioning)

PackerLite drives a VM's unattended first-boot setup after `VMBuilder.swift` finishes installing it — macOS Setup Assistant for `.ipsw` builds, or a Linux first-boot/OEM installer for `.iso` builds — via a parsed `boot_command`, the same concept as HashiCorp Packer's `boot_command` / `packer-plugin-tart`, built natively with no external binary or plugin. It only runs when `--autoinstall` is passed to `build`/`create`; there's no automatic provisioning otherwise. The two source types resolve their template very differently:

- **IPSW (macOS)**: `PackerLiteTemplateResolver.resolve(...)` (`Sources/cakedlib/PackerLite/PackerLiteTemplateResolver.swift`) picks the template in this order, throwing if none apply: explicit `--template <path>` → macOS version auto-detected from the IPSW filename (`MacOSVersion.detect(fromIPSWFilename:)`, Apple's `UniversalMac_<version>_<build>_Restore.ipsw` convention, which also yields the dotted version string, e.g. "15.6") → explicit `--macos-version` (`monterey`/`ventura`/`sonoma`/`sequoia`/`tahoe`/`goldengate`) → failure. Built-in templates are bundled as `CakedLib` SPM resources at `Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml` (currently `sequoia`, `tahoe`, `monterey`, `ventura`, and `sonoma` — no `goldengate` template exists yet). The detected codename/version are persisted unconditionally into `CakeConfig.osName`/`osRelease` (regardless of `--autoinstall`), so a later standalone `caked provision` run knows what the VM is without the original IPSW.
- **ISO (Linux)**: no built-in templates ship — `VMBuilder` only runs PackerLite for an ISO build when **both** `--autoinstall` and an explicit `--template <path>` are given (`Sources/cakedlib/VMBuilder.swift`, the `imageSource == .iso` branch after cloud-init setup). Distros with their own cloud-init/subiquity-style autoinstall (Ubuntu) keep using that existing path instead and don't pass `--template`. `caker`'s VM creation wizard (`Sources/caker/Views/VirtualMachineWizard.swift`) surfaces a YAML file picker for non-Ubuntu ISO sources and refuses to let you enable autoinstall without one.

In both cases the VM's account always comes from `CakeConfig.configuredUser`/`configuredPassword` (`--user`/`--password`), injected into the template as `${var.username}`/`${var.password}` — templates must not declare their own.

**`PackerLiteEngine`** (`Sources/cakedlib/PackerLite/PackerLiteEngine.swift`) has two entry points: `provision(location:config:template:runMode:progressHandler:)` boots the VM headlessly, waits for an IP, drives it, and shuts it down — used by `VMBuilder`'s build-time path. `provision(vm:template:runningIP:runMode:progressHandler:)` just drives an already-running `VirtualMachine` — used directly by the standalone `caked provision` command (`Sources/caked/Commands/Provision.swift`), which boots the VM itself with a visible UI window via `VMRunHandler` (so the operator can watch) instead of assuming a caller already booted it headlessly. `provision` accepts non-macOS VMs too as long as `--template` is given (macOS VMs still auto-resolve from the VM's stored `osName`); either way it installs the cakeagent once an IP is available, since ISO Linux VMs that skipped cloud-init won't have it yet. Both entry points mark `CakeConfig.provisioned = true` on success (see below) via the shared driving path.

Template `boot_command` entries are `{title, command}` objects (not bare strings) — the `title` surfaces as a progress substep and in logs. `BootCommand.swift`'s token vocabulary covers waits, text/press/click, `<leftShiftOn>`/`<leftShiftOff>`-style modifier holds (including `<fnOn>`/`<fnOff>`), `F1`–`F20`, `<click 'On-screen text'>` (Vision OCR), and `<keyboard 'source-id'>` to switch the active TIS keyboard-layout translator at runtime (`'current'` captures whatever layout is active on the host). `PackerLiteDriver` synthesizes `CGEvent`/`NSEvent`s directly against the VM's rendered `NSView` — it no longer wraps `VNCInputHandler`, just reuses the same synthesis technique in-process.

Everything under `Sources/cakedlib/PackerLite/` (driver, engine, resolver, template/`boot_command` parsing, and the resource-bundled `.packerlite.yaml` templates) is part of `CakedLib` itself — there is deliberately **no separate `PackerLite` SPM target**. There was one originally, split out for unit-testability, but it forced `GRPCLib` to depend on it too (for the `--macos-version` CLI option's type), and `CakedLib` already depends on `GRPCLib` — so keeping a shared leaf target meant mirroring an entire extra native target in both Xcode projects (see below) just to avoid one small enum duplication. It was folded back into `CakedLib`.

**`MacOSVersion` is intentionally duplicated**: `GRPCLib` can't depend on `CakedLib` (circular — `CakedLib` depends on `GRPCLib`), but `BuildOptions.macosVersion` (`Sources/grpc/options/BuildOptions.swift`) still needs a typed, `ExpressibleByArgument` enum for CLI validation. So `GRPCLib` declares its own small `MacOSVersion` enum (same six cases — `monterey`/`ventura`/`sonoma`/`sequoia`/`tahoe`/`goldengate`, raw values default to the case names) independent of `CakedLib`'s `MacOSVersion` (`Sources/cakedlib/PackerLite/MacOSVersion.swift`, which owns the actual template-selection logic). `VMBuilder.swift` bridges the two by raw value (`MacOSVersion(rawValue: options.macosVersion.rawValue)`) — keep both enums' cases in sync if you ever add one.

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
