---
layout: page
title: Troubleshooting
nav_order: 6
---

# Troubleshooting

## Build Signed Scripts Fail

**Symptoms:**
- `./Scripts/build-signed-debug.sh` or `./Scripts/build-signed-release.sh` exits with an error

**Checks:**
- Provisioning profile exists in `Resources/`
- Entitlements files are present and valid
- Local Xcode signing identity is configured

**Solutions:**
1. Verify signing certificates in Keychain Access
2. Check provisioning profile validity
3. Review entitlements configuration
4. Ensure Xcode project signing settings match

## Swift Package Resolution Issues

**Symptoms:**
- Dependency resolution loops or fails
- Build errors related to missing dependencies

**Checks:**
- Run package resolution again from Xcode
- Run `swift build` from the repository root
- Clear derived data/build cache if needed

**Solutions:**
1. Clean build folder: `Product → Clean Build Folder` in Xcode
2. Reset package caches: `File → Packages → Reset Package Caches`
3. Delete `Package.resolved` and re-resolve
4. Check network connectivity for external dependencies

## Wiki Publication Fails

**Symptoms:**
- `publish-wiki.sh` says it cannot access `<repo>.wiki.git`

**Checks:**
- Wiki feature is enabled in GitHub repository settings
- Token exists: `GITHUB_TOKEN` or `GH_TOKEN`
- SSH mode if needed: `USE_SSH=1`

**Solutions:**
1. Enable wiki in GitHub repository settings
2. Configure authentication token
3. Use SSH if HTTPS fails: `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`

## Runtime Issues

### Daemon Won't Start

**Symptoms:**
- `caked` fails to start
- Connection errors from `cakectl`

**Solutions:**
1. Check if another instance is running
2. Verify permissions and entitlements
3. Check system logs for detailed errors
4. Ensure required macOS frameworks are available

### VM Operations Fail

**Symptoms:**
- VM creation or start operations fail
- Virtualization errors

**Solutions:**
1. Verify macOS Virtualization framework availability
2. Check system resources (CPU, memory, disk)
3. Review VM configuration parameters
4. Ensure proper entitlements for virtualization

## Useful Commands

```bash
# Build from command line
swift build

# Publish wiki with token
GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh Fred78290 caker

# Publish wiki via SSH
USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker

# Check system logs
log show --predicate 'subsystem contains "caker"' --last 1h

# Clean Swift build
swift package clean
```

## Getting Help

If you're still experiencing issues:

1. Check the [FAQ](faq) for common questions
2. Review the [Development](development) guide for setup details
3. Search or create an issue on [GitHub](https://github.com/Fred78290/caker/issues)
4. Include system information, error messages, and steps to reproduce