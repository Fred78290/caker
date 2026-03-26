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
[![Documentation](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://caker.aldunelabs.com)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/Fred78290/caker/blob/main/LICENSE)


It is designed around two complementary components:
- `caked`: the daemon/service that performs VM, image, and network operations
- `cakectl`: the CLI client used to control `caked`

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

## Repository map

- `Sources/caked/` – daemon entrypoints and commands
- `Sources/cakectl/` – CLI commands and client logic
- `Sources/cakedlib/` – shared core library
- `Sources/grpc/` – gRPC layer and generated interfaces
- `Tests/` and `Caker/CakerTests/` – test suites
