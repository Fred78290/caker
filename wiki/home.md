# Caker Wiki

Welcome to the Caker documentation wiki.

**Caker** is a Swift-native virtualization platform for macOS that streamlines VM lifecycle management from development to operations.
It combines a powerful daemon (`caked`) with a practical CLI (`cakectl`) so teams can build, run, inspect, and automate virtual machines consistently.
If you run `caked` as a service, use `cakectl` as the primary interface.

Caker is a virtualization toolchain used to build, launch, and manage virtual machines on macOS.

It is designed around three complementary components:
- `caked`: the daemon/service that performs VM, image, and network operations
- `cakectl`: the CLI client used to control `caked`
- `Caker.app`: the GUI client used to control `caked` or standalone

In typical usage, `cakectl` sends commands to `caked` through gRPC, and `caked` executes lifecycle actions such as build, launch, start/stop, image pull/push, and network management.

Use this wiki as the central reference for architecture, command usage, troubleshooting, and operational workflows.

Contributor guide: [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Quick links

- [Getting Started](getting-started)
- [Architecture](architecture)
- [Development](development)
- [Troubleshooting](troubleshooting)
- [FAQ](faq)
- [Release Notes](release-notes)
- [Command Summary](command-summary)
- [Cheat Sheet](cheat-sheet)
- [Private Policy](privacy-policy)

## Repository map

- `Sources/caked/` – daemon entrypoints and commands
- `Sources/cakectl/` – CLI commands and client logic
- `Sources/cakedlib/` – shared core library
- `Sources/caker/` – GUI app
- `Sources/grpc/` – gRPC layer and generated interfaces
- `Tests/` and `Caker/CakerTests/` – test suites
