---
layout: home
title: Home
nav_order: 1
---

# Caker

![Caker App Icon]({{ '/assets/images/CakedAppIcon.png' | relative_url }}){: width="192" }

**Caker** is a Swift-native virtualization platform for macOS that streamlines VM lifecycle management from development to operations. It combines a powerful daemon (`caked`) with a practical CLI (`cakectl`) so teams can build, run, inspect, and automate virtual machines consistently.

[![Build](https://github.com/Fred78290/caker/actions/workflows/release.yaml/badge.svg?branch=main)](https://github.com/Fred78290/caker/actions/workflows/release.yaml)
[![Publish Wiki](https://github.com/Fred78290/caker/actions/workflows/publish-wiki.yaml/badge.svg?branch=main)](https://github.com/Fred78290/caker/actions/workflows/publish-wiki.yaml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/Fred78290/caker/blob/main/LICENSE)

## Features

Available features include:
- Port forwarding between the VM and the host using TCP or Unix sockets
- Dynamic port forwarding updates while virtual machines are running
- Network creation in bridge, hosted, or NAT mode
- Cloud-Init support for VM initialization and customization
- Automatic installation of an in-guest agent, with source code in [cakeagent](https://github.com/Fred78290/cakeagent)

## Components

### caked - Core Daemon
`caked` is the core daemon process that handles virtual machine lifecycle management, including building, running, and orchestrating virtual machines with configuration-driven workflows.

### cakectl - Command Line Interface
`cakectl` is the command-line interface tool used to interact with `caked`. It provides commands to:
- Build and deploy applications
- Manage virtual machine configurations
- View logs and status
- Control the daemon process

### Caker.app - macOS Desktop Application
`Caker.app` is the macOS desktop application that provides a graphical experience for working with virtual machines managed by `caked`. It acts as the user-facing control plane of the project and is designed for day-to-day local development workflows.

## Quick Start

Get started with Caker by following our [Getting Started Guide](getting-started).

## Documentation

- [Getting Started](getting-started) - Setup and first steps
- [Architecture](architecture) - System design and components
- [Development](development) - Contributing and building from source
- [Command Summary](command-summary) - Complete command reference
- [Troubleshooting](troubleshooting) - Common issues and solutions
- [FAQ](faq) - Frequently asked questions
- [Release Notes](release-notes) - Version history and changes

## Repository Map

- `Sources/caked/` – daemon entrypoints and commands
- `Sources/cakectl/` – CLI commands and client logic
- `Sources/cakedlib/` – shared core library
- `Sources/grpc/` – gRPC layer and generated interfaces
- `Tests/` and `Caker/CakerTests/` – test suites

## Contributing

See our [Contributing Guide](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md) for details on how to contribute to the project.

## License

This project is licensed under the [AGPL v3 License](https://github.com/Fred78290/caker/blob/main/LICENSE).