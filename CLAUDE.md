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

## Code Organization Conventions

- **Adding a command**: Mirror it in both `Sources/caked/Commands/` and `Sources/cakectl/Commands/` where applicable. Use `ArgumentParser` with `CommandConfiguration` metadata including `abstract:` and `discussion:`.
- **Shared logic**: Put it in `CakedLib` (`Sources/cakedlib/`), not in the executables.
- **gRPC changes**: Edit `service.proto`, regenerate, then update both server (`caked`) and client (`cakectl`/`caker`) sides.
- **Localization**: Use `String(localized: "...")` throughout; localization source files are in `Resources/Localizable.xcstrings`.

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
