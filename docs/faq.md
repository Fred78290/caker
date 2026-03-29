---
layout: default
title: FAQ
nav_order: 7
---

# FAQ

## General Questions

## What is the difference between `caked` and `cakectl`?

- `caked` is the background daemon that performs operations.
- `cakectl` is the CLI client used to send commands to `caked`.

Think of it like Docker: `caked` is like the Docker daemon, and `cakectl` is like the `docker` CLI command.

## What branch should I base my work on?

- Use `main` as the base branch for contributions in this repository.

### What platforms are supported?

Currently, Caker only supports macOS due to its reliance on the Apple Virtualization framework. Linux and Windows support is not planned at this time.

## Development Questions

## Why does wiki publishing fail with “repository not found”?

Common causes:
- Wiki feature is not enabled in repository settings.
- Missing or invalid GitHub authentication token.
- Insufficient permissions for private repository wiki access.

## How do I publish wiki pages quickly?

```bash
# Using token authentication
GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh Fred78290 caker

# Using SSH authentication
USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker
```

### Why do build scripts fail with signing errors?

This typically happens when:
- Provisioning profiles are missing or expired
- Signing certificates aren't properly configured
- Entitlements files are invalid

Check the [Troubleshooting](troubleshooting) guide for solutions.

## Usage Questions

### Can I run multiple VMs simultaneously?

Yes, Caker supports running multiple VMs concurrently, limited by your system's available resources (CPU, memory, disk space).

### How do I configure networking for VMs?

Caker supports multiple networking modes:
- **Bridge mode**: Direct access to host network
- **Hosted mode**: VM-to-host communication
- **NAT mode**: Outbound internet access with port forwarding

See the [Command Summary](command-summary) for network configuration commands.

### How do I transfer files between host and VM?

You can use:
- Mount points configured during VM creation
- The `exec` command to run file transfer tools
- Network file sharing protocols

### What image formats does Caker support?

Caker works with:
- Custom VM images built with Caker
- Images from configured registries
- Imported images from other virtualization platforms (via `import` command)

## Integration Questions

### Can I use Caker in CI/CD pipelines?

Yes, Caker is designed to work in automated environments. The CLI interface (`cakectl`) provides scriptable commands for VM lifecycle management.

### Is there REST API support?

Currently, Caker uses gRPC for communication between `cakectl` and `caked`. REST API support is not available but could be added in the future.

### How does Caker compare to other virtualization tools?

Caker is specifically designed for:
- macOS environments using the Virtualization framework
- Developer workflows and automation
- Swift/native integration
- Configuration-driven VM management

It differs from tools like Docker (containers) or VirtualBox (cross-platform VMs) by focusing on native macOS virtualization with a developer-friendly interface.

## Getting More Help

Don't see your question answered here?

1. Check the [Troubleshooting](troubleshooting) guide
2. Review the [Command Summary](command-summary) for usage details
3. Visit the [Development](development) section for contribution info
4. Open an issue on [GitHub](https://github.com/Fred78290/caker/issues)
