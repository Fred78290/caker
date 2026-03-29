---
layout: page
title: Development
nav_order: 4
---

# Development

## Code organization

- `Sources/cakectl/Commands/` – CLI command handlers
- `Sources/caked/Commands/` and `Sources/caked/Handlers/` – daemon command and runtime handlers
- `Sources/cakedlib/` – shared utilities, config, and core abstractions

## Tests

Primary test locations:

- `Tests/CakerTests/`
- `Caker/CakerTests/`
- `integration/tests/`

## Contribution workflow

1. Create a branch from `main`.
2. Implement focused changes.
3. Run relevant tests and build checks.
4. Open a pull request with clear context.

Contributor guide:

- [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Useful scripts

- `Scripts/build-signed-debug.sh` - Build debug version with signing
- `Scripts/build-signed-release.sh` - Build release version with signing
- `Scripts/build-signed-snapshot.sh` - Build package and dmg with signing
- `Scripts/act.sh` - Local GitHub Actions testing
- `Scripts/run-signed-caked.sh` - Run signed daemon
- `Scripts/run-signed-cakectl.sh` - Run signed CLI

## Development Environment

### Requirements
- macOS (required for Virtualization framework)
- Xcode with Swift toolchain
- Signing certificates and provisioning profiles
- Optional: GitHub CLI for pull request management

### Getting Started
1. Clone the repository
2. Run `./Scripts/build-signed-debug.sh` to build
3. Use the run scripts to test components
4. Run tests via Xcode or command line

### Code Style
- Follow Swift conventions
- Use clear, descriptive naming
- Add documentation for public APIs
- Include tests for new functionality