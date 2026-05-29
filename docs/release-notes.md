---
layout: default
title: Release Notes
nav_order: 8
---

# Release Notes

## 2026-05-29

### Added
- **LXD REST API**: `caked service listen --rest` enables an LXD-compatible HTTP/HTTPS API server at `/1.0/instances`, `/1.0/networks`, `/1.0/images`, `/1.0/operations`, `/1.0/certificates`, `/1.0/identities`, and `/1.0/auth-groups`. Default ports: 8443 (HTTPS/mTLS), 8080 (HTTP). Override with `--rest-port`.
- **Web UI**: `caked service listen --web-ui <path>` serves the bundled React/Vite frontend at `/ui`. Accepts a directory or a `.zip` archive.
- **`caked convert` command**: converts QCOW2 or VMDK disk images to raw format using a pure-Swift implementation (no external tools required). Flags: `--source-format qcow2` (default) or `--source-format vmdk`.
- **`cakectl vnc` command**: opens a native VNC client window connected to a running VM's display. Automatically tunnels the VNC connection through `caked`.
- **Ubuntu 26.04 (Resolute Rhino)** build script support updated.

### Updated
- TLS certificate handling hardened: force-unwrap removed, mTLS CA certificate required for password bypass.
- Basic Auth credential moved to in-memory storage (no longer written to `sessionStorage`).
- `About` view updated to reflect remote control (CLI, GUI, and Web API) capabilities.

### Notes
- The REST API is LXD-compatible; existing LXD clients and tooling can connect directly to `caked`.
- The Web UI development proxy (`VITE_API_TARGET`) defaults to `http://127.0.0.1:8080`.

## 2026-03-26 (Git log summary - main)

### Added
- See commit highlights below.

### Updated
- Refactor ensurePrivilegedBootstrapFiles call
- Update Sources/caker/Model/AppState.swift
- Terminate app and alert user on privileged bootstrap failure
- Use singleton pattern for AppState and automate bootstrap file check
- Clarify error message for IPSW usage on non-ARM architectures
- Use shared constant for the caked command name
- Improve error feedback for virtual machine loading failures
- Adjust daemon launch priority to background
- Refactor service management and introduce manual daemon control
- Refactor AppState service loading and mode switching logic
- Configure window title and toolbar style for HomeView
- Add run mode status indicator to the HomeView toolbar
- Group navigation toolbar items
- Finish shell stream when closing the interactive shell
- Hide background visibility for VM status toolbar items
- Update Sources/caker/MainApp.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Refactor privileged operations to use native Authorization Services

### Notes
- Summary generated automatically from recent git commits on branch `main`.
- Command used: `git log --no-merges --oneline -n 20 -- Sources wiki`.


## 2026-03-03 (Git log summary - main)

### Added
- See commit highlights below.

### Updated
- Adds helper for consistent virtual machine document creation
- Adds handler for retrieving VM infos and configuration
- Refactors agent helper creation for consistency
- Refactors command handlers to use provider instead of client
- Adds utility to instantiate agent helpers with varied inputs
- Simplifies init call syntax for data conversion
- Refactors info retrieval to support VMLocation input
- Removes runMode check when selecting gRPC client usage
- Adds option to include VM config in list output
- Adds option to include VM config in list commands
- Use display.cgSize for document view sizing
- Add Codable conformance to SupportedPlatform
- Make enum codable and remove unused conformances
- Simplifies console config to use String instead of struct
- Standardizes display size types across the application
- Refactors `InfosHandler` file structure
- Adds optional VM configuration to list requests
- Refactor config mapping and introduce public model
- Refactors VM hardware identifier storage
- Centralizes VM configuration and image source types

### Notes
- Summary generated automatically from recent git commits on branch `main`.
- Command used: `git log --no-merges --oneline -n 20 -- Sources wiki`.


## 2026-02-26 (Git log summary - main)

### Added
- Grand Central Dispatch capabilities for live VM/system status streaming (including `gcd` command and updater flow).
- gRPC methods for Grand Central dispatcher/update paths and related status stream handling.
- Additional project dependencies and test plan scaffolding.

### Updated
- Service startup/shutdown behavior refined.
- VM start command help/descriptions improved.
- CLI help request and error handling improved.
- VM/network runtime reliability improved (status updates, gRPC stability, network startup logic).
- Shell command handling improved (including safer argument quoting).

### Notes
- Summary generated from recent commits on branch `main`.
- See git history for full details: `git log --oneline`.

## 2026-02-26

### Added
- Initial wiki structure published.
- Getting Started, Architecture, Development, Troubleshooting, and FAQ pages.
- Wiki publishing script: `Scripts/publish-wiki.sh`.

### Updated
- Contribution guidance aligned to base branch `main`.
- Wording and structure polished across core wiki pages.

### Notes
- Wiki publication requires GitHub Wiki access on the target repository.
- For private repositories, use `GH_TOKEN`/`GITHUB_TOKEN` or `USE_SSH=1`.

## How to update this wiki

1. Edit pages in the local `wiki/` directory.
2. Review changes and keep navigation in sync (`Home.md` and `_Sidebar.md`).
3. (Optional) Create a dated release note entry automatically with:
	- `./Scripts/new-wiki-release-entry.sh`
	- or `./Scripts/new-wiki-release-entry.sh YYYY-MM-DD`
4. Publish with:
	- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
	- or `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
5. Add notable documentation updates in the new dated entry.

## Entry template

Copy/paste this block for the next update:

```markdown
## YYYY-MM-DD

### Added
- ...

### Updated
- ...

### Notes
- ...
```
