# Command Summary

This page summarizes the `ArgumentParser` commands implemented in:
- `Sources/caked/Commands`
- `Sources/cakectl/Commands`

## Command model

- `caked` is the local daemon/hypervisor command surface.
- `cakectl` is the gRPC client command surface.
- Most VM/image/network operations exist on both sides with similar names.

## Common command groups (`caked` and `cakectl`)

### VM lifecycle and execution

- `build` — create a VM from a cloud image, downloading and converting it as needed; cloud-init runs on first boot.
- `launch` — build and start a VM.
- `spawn` (alias: `create-from-disk`) — create a VM from an **existing** root disk (raw image file or physical block device) without cloud-init. See [Spawning from an existing disk](#spawning-from-an-existing-disk).
- `spawn-start` — same as `spawn`, then immediately start the VM.
- `start` / `stop` / `restart` / `suspend` — control VM runtime state.
- `delete` / `duplicate` / `rename` / `configure` — manage VM lifecycle and configuration.
- `list` / `infos` / `waitip` — inspect VM inventory, details, and IP readiness.
- `exec` / `sh` — execute commands in guest VM context.
- `mount` / `umount` — manage VM mounts.
- `vnc` — open a native VNC client window connected to a running VM's display.

### Images and registries

- `image` group: `list`, `info`, `pull`.
- `pull` / `push` — transfer VM images.
- `login` / `logout` — registry authentication.
- `remote` group: `add`, `delete`, `list`.
- `template` group: `create`, `delete`, `list`.
- `purge` — cleanup caches/images according to retention/budget options.

### Networks

- `networks` group: `infos`, `list`, `create`, `configure`, `delete`, `start`, `stop`.

### Compose

- `compose` group: `up`, `down`, `ps`, `rm`, `ls`, `init`. Manage multi-VM stacks defined in a `compose.yml` file. See [Compose](compose) for full reference.
  - `up [-f file] [--wait-ip-timeout N] [services...]` — create and start services in `depends_on` order.
  - `down [-f file] [--force] [services...]` — stop services in reverse order.
  - `ps [-f file] [services...]` — show service status.
  - `rm [-f file] [-s/--stop] [--force] [services...]` — remove service VMs and unregister the project.
  - `ls` — list all registered compose projects (`cakectl` only).
  - `init [-f/--force]` — write a commented `compose.yml` template in the current directory.

## `caked`-specific commands

- `certificates` group:
  - `get` — show certificate paths
  - `generate` — generate TLS certs
  - `agent` — generate agent certs
- `convert` — convert a VMDK or QCOW2 disk image to raw format (pure Swift, no external tools required).
  - `--source-format` / `-f` — source format: `qcow2` (default) or `vmdk`.
- `service` — service/daemon management entry point.
  - `install` — install `caked` as a launchctl agent.
  - `listen` — start the daemon listener with the following notable flags:
    - `--rest` — enable the LXD-compatible REST API server (default port 8443 for HTTPS, 8080 for HTTP).
    - `--rest-port <port>` — override the REST API listen port.
    - `--web-ui <path>` — serve the bundled web UI from a directory or `.zip` archive at `/ui`.
    - `--address` / `-l` — override the gRPC listen address.
    - `--insecure` — disable TLS.
  - `status` — report daemon status.
  - `stop` — stop the running daemon.
- `vmrun` — internal VM runtime command (hidden/internal).
- `import` — import external VM (Multipass or VMware Fusion) from file/URL.
- `networks` extra internal/admin subcommands:
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (internal)

## `cakectl`-specific commands

- `certificate` — Manage certificate to authenticate API rest.

## macOS IPSW installation

`build` accepts an `.ipsw` file as the image source on Apple Silicon hosts. The installer back-end is chosen automatically based on the IPSW content.

### Back-end selection

| Guest macOS version | Back-end used | Availability |
| --- | --- | --- |
| macOS 26 or older | `VZMacOSInstaller` (system framework) | All builds |
| macOS 27 (Golden Gate) or newer | AMRestore (`AppleMobileDeviceRestore` SPI) | Non-App Store builds only |

The AMRestore path can be force-enabled for any IPSW by setting the `CakerForceVirtualInstallBackend` UserDefaults key (useful for testing):

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Remove the override when you are done:

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### How the AMRestore path works

1. The VM is booted in **DFU mode** using the private `_forceDFU` property on `VZMacOSVirtualMachineStartOptions`.
2. Caker waits for the VM to appear as a restorable AMRestore device (matched by its ECID — the unique chip identifier embedded in the machine identifier).
3. The IPSW is handed to `AMRestorableDeviceRestore` which performs personalization against `gs.apple.com` and flashes the image. The VM shuts down on completion.

Restore logs are written to `~/Library/Application Support/Caker/VirtualInstall/Logs/` (four files: `global.log`, `host.log`, `device.log`, `serial.log`).

### Limitations

- **Apple Silicon only** — AMRestore SPI does not exist on Intel Macs.
- **Non-App Store builds only** — AMRestore communicates with `com.apple.mobile.restored` and other system daemons that are blocked by the App Sandbox.
- Requires macOS 26 or later on the **host**.

## Notes

- Some commands are internal or hidden in help output on `caked` (`vmrun`, some `networks` subcommands).
- Exact flags/options are defined in the corresponding `*Options` types and command files.
- If the `caked` service is already active, do not run `caked` commands directly; use `cakectl` to interact with the running service.

## Examples

### Basic VM Operations
```bash
# Create and start a VM
cakectl launch myvm --image ubuntu:22.04

# List running VMs
cakectl list

# Execute command in VM
cakectl exec myvm -- ls -la

# Stop VM
cakectl stop myvm
```

### Image Management
```bash
# Pull an image
cakectl pull ubuntu:22.04

# List local images
cakectl image list

# Push custom image
cakectl push myregistry.com/myimage:latest
```

## Spawning from an existing disk

`spawn` and `spawn-start` register a new VM that boots directly from an **existing** disk — a raw image file you already have, or a physical block device (`/dev/diskN`). No image is downloaded or converted, and cloud-init does not run by default.

### When to use `spawn` vs `build`

| | `build` / `launch` | `spawn` / `spawn-start` |
| --- | --- | --- |
| Root disk | Downloaded / converted from URL | Provided by you (image or block device) |
| cloud-init | Runs on first boot | Off by default; opt in with `--use-cloud-init` |
| Typical use | Fresh Linux/macOS VMs from cloud images | Pre-configured images, physical disks, migrated VMs |

### Syntax

```text
caked spawn [options] <name> <root-disk>
caked spawn-start [options] <name> <root-disk>
```

`<root-disk>` can be:

- An absolute or `~`-expanded path to a raw disk image (`/path/to/disk.img`)
- A physical block device (`/dev/disk4`) — requires macOS 14 or later

### Options

| Flag | Default | Description |
| --- | --- | --- |
| `-c, --cpus <num>` | `1` | Number of vCPUs |
| `-m, --memory <MB>` | `512` | RAM in megabytes |
| `--os <linux\|darwin>` | `linux` | Guest OS type |
| `--disk <path>` | — | Additional attached disk (repeatable) |
| `-u, --user <name>` | `admin` | Username caked uses to connect to the guest (exec/sh) |
| `-w, --password <pass>` | — | Password for the guest user |
| `--nvram <path>` | — | Existing NVRAM / auxiliary-storage file to copy (required for macOS on Apple Silicon when not auto-fetched) |
| `-a, --autostart` | off | Start VM automatically at boot |
| `-t, --nested` | off | Enable nested virtualisation |
| `--suspendable` | off | Optimise for VM suspension (macOS guests) |
| `-p, --publish <spec>` | — | Port forwarding, docker syntax (repeatable) |
| `-v, --mount <spec>` | — | Virtio-FS directory share (repeatable) |
| `-n, --network <spec>` | — | Network interface (repeatable) |
| `--bridged` | off | Add one bridged network interface |
| `--net.ifnames <bool>` | `true` | Use predictable interface names (eth0 → enp…) |
| `--display <WxH>` | `1024x768` | Guest screen resolution |
| `--socket <url>` | — | Virtio socket (repeatable) |
| `--console <url>` | — | Serial console URL |
| `--use-cloud-init` | off | Run cloud-init on first boot (Linux only) |

`spawn-start` also accepts `--wait-ip-timeout <seconds>` (default `180`).

#### NVRAM behaviour

| Platform | `--nvram` provided | `--nvram` omitted |
| --- | --- | --- |
| Linux (any arch) | ignored — fresh EFI variable store is always created | fresh EFI variable store created |
| macOS (Apple Silicon) | provided file is copied as the VM's auxiliary storage | hardware model fetched from Apple metadata; fresh auxiliary storage created automatically |

#### cloud-init when using `--use-cloud-init`

When `--use-cloud-init` is passed (Linux only), the following additional options become meaningful:

| Flag | Description |
| --- | --- |
| `-i, --ssh-authorized-key <path>` | SSH authorized-key file to inject |
| `-g, --main-group <name>` | Primary group for the user (default `adm`) |
| `-o, --other-group <name>` | Additional groups (default `sudo`, repeatable) |
| `-k, --clear-password` | Allow password-based SSH login |
| `--cloud-init <path\|url\|->`| Custom user-data file or URL (`-` for stdin) |
| `--network-config <path>` | Custom cloud-init network-config file |

Without `--use-cloud-init`, none of these options have any effect — they are accepted but ignored.

### Spawn examples

```bash
# Register a VM from a raw image, 2 vCPUs, 2 GiB RAM
caked spawn myvm ~/images/ubuntu-24.04.raw -c 2 -m 2048

# Register and immediately start, with NAT network and port forwarding
caked spawn-start myvm ~/images/ubuntu-24.04.raw \
  -c 4 -m 4096 \
  --network nat \
  -p 2222:22/tcp

# Boot from a physical disk, specifying the guest credentials for exec/sh
caked spawn diskvm /dev/disk4 --os linux -c 2 -m 4096 -u ubuntu -w secret

# macOS guest from an existing disk — copy its NVRAM (Apple Silicon)
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192 \
  --nvram ~/vms/macos.nvram

# macOS guest — let caked fetch the hardware model and create NVRAM automatically
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192

# Spawn with cloud-init enabled and a custom SSH key
caked spawn webvm ~/images/ubuntu-24.04.raw \
  -c 2 -m 2048 -u ubuntu -w secret \
  --use-cloud-init -i ~/.ssh/id_ed25519.pub
```

### Physical block device (`/dev/diskN`)

When `<root-disk>` points to a block device rather than an image file, caked:

1. Checks whether any volumes on the disk are currently mounted.
2. If mounted, prompts to unmount them automatically (GUI) or aborts with an error message (daemon/headless mode) — you must run `diskutil unmountDisk /dev/diskN` manually first.
3. Opens the device with an **exclusive lock** (`O_EXLOCK`) in read-write mode.
4. Passes the open file descriptor to Apple's `Virtualization.framework` as a `VZDiskBlockDeviceStorageDeviceAttachment`.

The lock is held for the entire lifetime of the VM, preventing macOS from re-mounting the disk while the VM is running.

> **Note:** Attaching physical block devices requires macOS 14 (Sonoma) or later and is **not supported in the App Store version**. The App Sandbox cannot acquire the exclusive lock (`O_EXLOCK`) required to open a block device safely. Use the direct-download build if you need raw disk access.

### Taking ownership of a physical device

macOS block devices (`/dev/diskN`) are owned by `root:operator` with mode `0660`. Ordinary users cannot open them read-write without additional privileges.

If caked reports a **permission denied** error for a block device, you have two options:

#### Option A — join the `operator` group (persistent, recommended)

```bash
sudo dseditgroup -o edit -a "$USER" -t user operator
```

Log out and back in (or start a new shell session) for the group membership to take effect. After that, every `/dev/diskN` device is accessible to you without `sudo`, and you never need to repeat this step.

#### Option B — change the device owner (per-session, resets on reboot)

```bash
sudo chown "$USER" /dev/disk4
```

This changes ownership of the specific node to your user. The change is **not persistent** — macOS resets device ownership on reboot or when the disk is reconnected.

#### Which option to choose

| | Option A (operator group) | Option B (chown) |
| --- | --- | --- |
| Persistent | Yes | No (resets on reboot / reconnect) |
| Scope | All block devices | One device at a time |
| Effort | Once per user account | Every time the disk is reconnected |
| Recommended | Yes | Quick one-off testing |

After granting access with either option, retry the `spawn` or `spawn-start` command — no other changes are needed.
