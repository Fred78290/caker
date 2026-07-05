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
GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker

# Using SSH authentication
USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker
```

### Why do build scripts fail with signing errors?

This typically happens when:
- Provisioning profiles are missing or expired
- Signing certificates aren't properly configured
- Entitlements files are invalid

Check the [Troubleshooting](troubleshooting) guide for solutions.

## macOS Installation Questions

### Why does macOS 27 installation fail at ~78% with `VZMacOSInstaller`?

This is a known `VZMacOSInstaller` regression ([utmapp/UTM#7746](https://github.com/utmapp/UTM/issues/7746)) that affects macOS 27 guests installed on macOS 26 hosts. Caker works around this automatically by switching to the `AppleMobileDeviceRestore` (AMRestore) backend whenever the IPSW targets macOS 27 or later.

### How does Caker decide which installation backend to use?

The choice is made at the start of each `build` (IPSW) install:

1. If `CakerForceVirtualInstallBackend` is `true` in UserDefaults → AMRestore.
2. If the IPSW's `operatingSystemVersion.majorVersion >= 27` → AMRestore.
3. Otherwise → `VZMacOSInstaller`.

### Is macOS 27 installation available in the App Store build?

Yes. The AMRestore path — which relies on the private `AppleMobileDeviceRestore` framework and the `com.apple.mobile.restored` daemon — is now enabled in the App Store build via the `USE_VIRTUAL_INSTALL_BACKEND` feature flag.

### How can I force the AMRestore backend for testing?

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Remove it when you are done:

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### Where can I find the restore logs?

AMRestore writes four log files to `~/Library/Application Support/Caker/VirtualInstall/Logs/`:

| File | Content |
| --- | --- |
| `global.log` | Global AMRestore engine messages |
| `host.log` | Host-side restore progress |
| `device.log` | Messages from the virtual device |
| `serial.log` | Serial output from the VM during restore |

## App Store Limitations

### Can I use physical block devices (raw disk mode) in the App Store version?

No. The App Store version runs inside the macOS App Sandbox, which prevents acquiring the exclusive lock (`O_EXLOCK`) that Caker requires when opening a physical block device (`/dev/diskN`). This restriction applies even though the sandbox grants temporary read-write access to `/dev`.

Affected operations:
- `caked spawn <name> /dev/diskN` — fails with a permission error.
- `caked spawn-start <name> /dev/diskN` — same.
- Any VM configuration that references a `/dev/diskN` path as a root or additional disk.

Raw image files (`.raw`, `.img`, `.qcow2` after conversion, etc.) stored in your home directory are not affected and work normally in the App Store version.

If you need to boot a VM directly from a physical block device, use the **direct-download build** of Caker available from the [GitHub releases page](https://github.com/Fred78290/caker/releases).

### Can I resize an ASIF disk from the command line in the App Store version?

No. Resizing an ASIF (Apple Sparse Image Format) disk relies on `diskutil image resize`, which the App Sandbox does not allow the `caked`/`cakectl` command-line interface or the background service to invoke. Running `configure --disk-size` on an ASIF disk fails with an explicit error in the sandboxed version.

Workarounds:

- **Use the Caker application** — resizing from the VM settings UI works normally, or
- **Run the command manually** in Terminal, with the VM stopped:

```bash
diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
```

When the resize is refused, the Caker application shows the exact command to run for your VM. Raw-format disks are not affected, and neither is the direct-download build. See [Disk formats: raw and ASIF](command-summary#disk-formats-raw-and-asif) for details.

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
- Images from configured registries (OCI, simplestream, HTTPS)
- Imported images from other virtualization platforms (via `import` command)
- QCOW2 and VMDK images converted to raw format with `caked convert`

Root disks can use the **raw** or **ASIF** (Apple Sparse Image Format, macOS 26+) format — see [Disk formats: raw and ASIF](command-summary#disk-formats-raw-and-asif).

## Integration Questions

### Can I use Caker in CI/CD pipelines?

Yes, Caker is designed to work in automated environments. The CLI interface (`cakectl`) provides scriptable commands for VM lifecycle management.

### Is there REST API support?

Yes. `caked` includes an optional LXD-compatible REST API server. Start it with the `--rest` flag:

```bash
caked service listen --rest
```

This exposes an HTTP/HTTPS API at `/1.0/instances`, `/1.0/networks`, `/1.0/images`, and other LXD-compatible endpoints. The default port is `8443` for HTTPS (mTLS) and `8080` for HTTP; override with `--rest-port`.

The primary interface remains gRPC (`cakectl` ↔ `caked`), but the REST API allows integration with LXD-compatible tooling and the bundled web UI.

See the [Architecture](architecture) page for a full endpoint reference.

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
