# Getting Started

## Prerequisites

- macOS
- Xcode + Swift toolchain
- Access to project signing assets (for signed build scripts)

## Build

Run one of the project scripts from the repository root:

- `./Scripts/build-signed-debug.sh`
- `./Scripts/build-signed-release.sh`

If build scripts fail, verify:
- provisioning profile availability
- signing entitlements in `Resources/`
- local Xcode signing configuration

## Core commands

The project contains two principal binaries:

- `caked` (daemon)
- `cakectl` (CLI)

Use the run helpers when needed:

- `./Scripts/run-signed-caked.sh`
- `./Scripts/run-signed-cakectl.sh`
