# Caker: Native Virtual Machines on macOS, from a Single Command to a Full Stack

*A Swift toolchain built on Apple's Virtualization framework, with a daemon (`caked`), a CLI (`cakectl`) and a desktop app (`Caker.app`) that work together*

![Caker](https://raw.githubusercontent.com/Fred78290/caker/main/Resources/CakedAppIcon.png)

---

If you develop on a Mac, you have probably needed a virtual machine at some point: a Linux box to test a deployment script, a clean macOS install to reproduce a bug, or a small cluster to try a database setup before it reaches staging. There are good tools for this already. Most of them handle one part of the job well, and you end up using one tool to download images, another to run them, and a set of shell scripts to configure the guests.

**Caker** tries to cover the whole job in one toolchain. It is open source, written entirely in Swift, and built directly on Apple's **Virtualization.framework**. It installs a macOS guest from an IPSW and clicks through Setup Assistant for you, and it installs Windows 11 from an ISO with no clicks at all. It runs a two-VM MariaDB + phpMyAdmin stack from a `compose.yml`. Each VM gets port forwarding, shared folders, an EC2-style metadata service and name resolution, and you can drive all of it from a terminal, a native desktop app or a web browser.

This article walks through what Caker is, how its pieces fit together, and the features you are most likely to use.

---

## Three components, one engine

Caker is organized around three programs that share the same core library (`CakedLib`):

| Component | What it does |
| --- | --- |
| **`caked`** | The daemon. It builds, runs and supervises VMs, manages images and networks, and can run as a `launchd` service in the background. |
| **`cakectl`** | The command-line client. It talks to `caked` over **gRPC** (TLS by default), so it works the same whether the daemon runs on your Mac or on another machine. |
| **`Caker.app`** | The SwiftUI desktop app. It can drive a running `caked`, or run VMs directly inside the app with no daemon at all. |

If you have used Docker, the split will look familiar: `caked` plays the role of the Docker daemon, and `cakectl` plays the role of the `docker` CLI.

```text
 cakectl ────────── gRPC ──┐
 Caker.app ──────── gRPC ──┤
 web UI / lxc ───── REST ──┤   (REST API is optional)
                           ▼
                         caked
                           │
           one service process per running VM
                           │
             Apple Virtualization.framework
```

Each running VM gets its own small service process, and the daemon collects their live status (CPU, memory, screenshots, state changes) and streams it to connected clients. This is how the desktop app shows live thumbnails of your VMs without polling.

Caker requires **macOS 15 or later**. macOS guests require Apple Silicon. Linux guests run on Apple Silicon and on Intel Macs, and so do **Windows 11** guests, as long as the ISO matches the Mac's architecture (Windows 11 for ARM on Apple Silicon, x64 on an Intel Mac).

---

## Your first VM in one command

Starting a Linux VM takes one command:

```bash
cakectl launch dev
```

With no image argument, `launch` uses the Ubuntu 24.04 cloud image: it downloads the image, converts it, creates the VM, runs cloud-init on first boot, installs Caker's in-guest agent and starts the VM. From there you use it the way you would use a container:

```bash
cakectl list                      # inventory
cakectl infos dev                 # details, IP addresses, status
cakectl exec dev -- uname -a      # run one command in the guest
cakectl sh dev                    # interactive shell
cakectl vnc dev                   # open a native VNC window on the VM's display
cakectl stop dev
```

`exec` and `sh` go through the **cakeagent**, a small agent installed in the guest automatically, so you don't need to set up SSH, look up the guest's IP address or copy keys.

Sizing and integration options use Docker-style syntax:

```bash
cakectl launch api \
  --cpus 4 --memory 8192 --disk-size 40 \
  --publish 8080:80/tcp \
  --mount ~/src/api:/workspace \
  --ssh-authorized-key ~/.ssh/id_ed25519.pub \
  ubuntu:noble
```

- **Port forwarding** over TCP, UDP or both, and **Unix socket forwarding** (for example, exposing a guest's `docker.sock` on the host). Forwarded ports can be **changed while the VM is running**.
- **Shared folders** use Virtio-FS, with read-only, `uid=` and `gid=` options.
- **Disk formats**: plain **raw** images, or **ASIF** (Apple Sparse Image Format) on macOS 26+, which only takes up the space the guest has actually written. ASIF is the default on hosts that support it.

---

## Images: use whatever source you have

Caker accepts several kinds of image sources, all through the same `build`/`launch` commands:

- **Simplestreams remotes**, LXD-style: `ubuntu:noble`, `ubuntu:24.04`. Add more with `cakectl remote add`.
- **Cloud images over HTTPS**: any qcow2 or raw image URL.
- **OCI registries**: `oci://ghcr.io/you/image:latest`. You can also `push` your own VMs to a registry and `pull` them on another machine, after a `cakectl login`.
- **ISO installers** for Linux distributions and for Windows 11.
- **IPSW restore images** for macOS guests.
- **Templates**: turn a configured VM into a reusable golden image with `cakectl template create my-vm golden`, then build new VMs from `template://golden`.

To save you from copying long URLs, Caker includes a **catalog of known images**. `--alias` replaces the URL with a short id, and `cakectl aliases` lists every id the catalog knows:

```bash
cakectl build --alias ubuntu2604 web
cakectl build --alias fedora44Server --autoinstall db
cakectl build --alias macos26 --autoinstall my-mac
```

A catalog entry also declares minimum resources, so `--alias macos26` creates a VM with at least 6 CPUs and 8 GiB of RAM even if you didn't specify them.

### Migrating from another tool

`caked import` imports VMs from **Multipass, VMware, Tart, UTM and VirtualBuddy**. For Tart, UTM and VirtualBuddy, `--no-copy-disk` references the existing disk in place instead of copying it. `caked convert` converts QCOW2 and VMDK images to raw format in pure Swift, without `qemu-img`. If you already have a disk, `spawn` creates a VM from an existing raw image or even from a physical block device (`/dev/diskN`).

---

## Unattended installs with PackerLite

Installing from an ISO or an IPSW usually means a long series of clicks: language, keyboard, disk, account, time zone, privacy screens, and for macOS, Setup Assistant on top of all that.

**PackerLite** automates those clicks. It is a provisioning engine built into Caker, inspired by HashiCorp Packer's `boot_command`, and it needs no external binary or plugin. Add `--autoinstall` to a build:

```bash
# macOS: the version is detected from the IPSW filename
cakectl build my-mac --autoinstall \
  https://updates.cdn-apple.com/.../UniversalMac_26.6_25G72_Restore.ipsw

# Linux: the distribution is detected from the ISO filename
cakectl build my-fedora --autoinstall ./Fedora-Workstation-Live-x86_64-42.iso
```

Caker installs the OS and then drives the first boot: it types and clicks through Setup Assistant or the distribution's installer, creates the account from your `--user`/`--password`, waits for an IP address, installs the agent and runs any post-install commands over SSH.

Built-in templates ship for **macOS 12, 13, 14, 15, 26 and 27**, and for **Fedora (Workstation and Server), CentOS Stream, RHEL, openSUSE, Debian, Alpine and Ubuntu (Desktop and Server)**.

A template is a YAML file made of titled steps. This excerpt from the built-in macOS 26 template fills in the account screen of Setup Assistant:

```yaml
boot_command:
  - title: Create a Mac Account
    commands:
      - <locate timeout=120 text='Create a Mac Account'>
      - <wait1s>
      - <tab repeat=6>
      - Managed via Caker
      - <tab>
      - ${var.username}
      - <tab>
      - ${var.password}
      - <tab>
      - ${var.password}
      - <tab repeat=2>
      - <spacebar>
```

Each `title` is reported as a progress step, so you can see where a run is, and where it stopped if it fails. A template can also declare a `pre_boot_command` (keystrokes for a GRUB menu, sent before the guest has an IP address) and a `post_boot_command` (shell commands run over SSH once the install is finished).

What makes these templates more reliable than a list of keystrokes and fixed delays:

- **On-screen text recognition.** `<click text='Continue'>` and `<locate text='…'>` use Apple's **Vision** framework to find text on the VM's screen, then click it or wait for it to appear. Fixed coordinates and fixed delays break whenever a screen loads a bit slower, so the templates wait for text instead. Alternatives such as `text="Accept|Continue"` handle wording that changes between installer versions.
- **Conditional steps**: `<skipStepIfNotFound>`, `<skipCommandIfNotFound>`, `<set>` variables and `condition:` blocks handle screens that only appear on some versions.
- **Real-world tokens**: modifier keys, function keys, keyboard layout switching, scrolling, mid-install `<reboot>`, and VoiceOver toggling for macOS's accessibility-based setup flow.
- **Variables**: `${var.username}`, `${var.password}`, `${var.hostname}` and `${var.ssh_authorized_key}` are always available. Add your own with `--var key=value`; they are stored, so you don't have to retype them for every build.

When a run fails, Caker keeps a **debug video** (`provision.mp4`, plain H.264) of the whole provisioning session, so you can see which screen the template stopped on.

You don't have to write templates by hand. **`caked record my-vm`** opens the VM in a window and records your clicks and keystrokes as you go through the installer, then writes a ready-to-edit `.packerlite.yaml`. Its "locate mode" uses the same text recognition to record `<click text=…>` steps instead of raw coordinates. The desktop app can record the same way from its toolbar. To re-run provisioning on a VM that has already been built, use **`cakectl provision my-vm`**. It opens a live VNC view so you can watch it from another machine.

---

## Windows 11, installed unattended

Windows 11 gets the same `--autoinstall` flag, but it is not installed by PackerLite. Windows' installer shows nothing on Virtualization.framework (Apple's firmware gives a guest no framebuffer, so the installer draws into nothing), which leaves PackerLite nothing to read. Caker has a dedicated installer for it instead:

```bash
cakectl build my-win11 iso:///path/to/Windows11_Client_arm64_en-us_26300_9457.iso \
  --cpus 4 --memory 8192 --disk-size 64 --user admin --password admin --autoinstall
```

Two things to know before you try it. **The ISO's file name must contain `windows`** (or `win11`/`win10`, for Microsoft's own names), because that is how Caker recognizes the image. And the ISO must match your Mac: Windows 11 for ARM on Apple Silicon, x64 on an Intel Mac. You download the ISO from Microsoft yourself.

What happens during the build:

- Caker turns the ISO into a bootable disk that Virtualization.framework can start (the ISO as downloaded has no partition table, so the firmware can't boot it), and edits Windows' setup environment so it runs Caker's own install script.
- That script partitions the VM's disk, applies the Windows image and drivers, and writes an answer file: a local administrator account from your `--user` and `--password`, no out-of-box experience, no Microsoft account screens.
- On first boot, Caker finishes the setup inside the guest and restarts the VM until it is done, then reports what it installed.

The result is a VM that reaches a working desktop with a display that follows the window's size, networking, shared folders (`--mount` folders show up as a drive, through WinFsp and virtio-fs), sound, an OpenSSH server with your keys already authorized, and the Caker agent running as a service. On an M4 Pro the install takes about three minutes and the first boot about four more.

A few options go through `--var`, and the desktop app's wizard offers the same ones:

| Variable | Effect |
| --- | --- |
| `WINDOWS_KEY` | A product key for the answer file |
| `WINDOWS_FRAME_SEGMENT_MIB` | The display driver's memory, 16 to 256 MiB, which sets the biggest screen the guest accepts (64, the default, holds 5120×3200) |
| `WINDOWS_AUDIO=0` | Leave the sound driver out |
| `WINDOWS_AUTOLOGON=1` | Log the account on at every start, not only once (the password then stays in the guest's registry in clear text, so it is off by default) |
| `WINDOWS_WHQL_ONLY=1` | Install only drivers Microsoft signed (virtio-win's own): no test-signing mode and no "Test Mode" watermark, but no sound, and the guest keeps its display size, so its window can't be resized |

Some of this rests on drivers that Windows does not ship. With virtio-win's stock display driver, Virtualization.framework shows a corrupted picture after a resolution change, and there is no Windows driver at all for its sound device. So Caker embeds a patched build of the open-source virtio-win display driver and an open-source virtio sound driver with a small change for Apple's device (both fixes are proposed upstream). Windows only loads signed kernel drivers, so they are **test-signed** with throwaway certificates, and the guest runs in test-signing mode: you will see a "Test Mode" watermark on the desktop.

The limits are worth knowing:

- **No TPM.** Virtualization.framework has no way to give a guest one, so BitLocker and device encryption are unavailable.
- **Any language works**: Caker installs the language of the ISO you give it, so use the French or Japanese ISO and you get a French or Japanese Windows. A reboot started from inside a running Windows guest stops the VM, so you start it again.
- **Not in the App Store edition.** The installer needs host tools the sandbox does not allow, and the App Store build does not run Windows VMs.
- **What has been tested:** Windows 11 ARM on Apple Silicon, and Windows 11 x64 on one Intel Mac (a Core i9), both in English and in French. Other Intel CPUs are untested.

---

## Multi-VM stacks with Compose

**Caker Compose** brings the Docker Compose workflow to virtual machines: you describe a stack in a `compose.yml`, in the Docker Compose format, and each service runs as a full VM.

```bash
cakectl compose init     # writes a working MariaDB + phpMyAdmin example
cakectl compose up       # builds and starts the services in depends_on order
cakectl compose ps
cakectl compose down
cakectl compose ls       # every registered project
```

You get the usual Compose fields (`image`, `ports`, `volumes`, `environment`, `networks`, `depends_on`, `deploy.resources.limits`), plus VM-specific extensions:

```yaml
name: myapp
services:
  mariadb:
    image: ubuntu:24.04
    ports: ["3306:3306"]
    environment:
      MYSQL_DATABASE: myapp
    deploy:
      resources:
        limits: { cpus: "2", memory: 2048M }
    disk: 20                      # GiB
    packages: [mariadb-server]    # installed with cloud-init on first boot
    post_commands:
      - systemctl restart mariadb

  phpmyadmin:
    image: ubuntu:24.04
    ports: ["8080:80"]
    depends_on: [mariadb]
    environment:
      PMA_HOST: mariadb.myapp.compose.internal
    write_files:
      - path: /etc/motd.d/welcome
        content: "Hello from Caker"
```

`packages`, `write_files` (inline content or a file read from the host), `package_update`, `package_upgrade` and `post_commands` are combined into a single cloud-init document. A service that would need a Dockerfile under Docker can usually be described in a few lines of YAML here.

### Services find each other by name

Look at `PMA_HOST` above. Caker runs a small DNS resolver on the NAT network that every VM is attached to. Each service can be reached as **`<service>.<project>.compose.internal`**, and any running VM, whether or not it belongs to a Compose project, as **`<vmname>.compose.internal`**. The resolver only answers for that domain, so it can't be used as an open resolver, and the guests' other DNS lookups are not affected. `compose up` starts the resolver automatically if it isn't already running. You can change the domain in the app's settings.

### Or keep it to one file per project

If a whole stack is more than you need, a **`.cakerenv`** file at the root of a repository does the job of a `Vagrantfile`: `cakectl init` writes a template, `cakectl up` creates or starts the project's development VM(s), and `cakectl down` stops them.

---

## Networking

- **NAT**, **bridged** (the VM is directly on your physical LAN) and **shared/hosted** vmnet networks that you create and manage:

  ```bash
  cakectl networks create --mode shared --gateway 192.168.105.1 \
    --dhcp-end 192.168.105.254 --netmask 255.255.255.0 shared-dev
  cakectl networks start shared-dev
  ```

- An **AWS-style Instance Metadata Service (IMDS)** for Linux guests, with IMDSv1 and IMDSv2 (token-based). `curl http://169.254.169.254/latest/meta-data/instance-id` works inside the guest as it would on EC2. That makes it easy to test cloud-oriented tooling locally: cloud-init datasources, agents and scripts that read their identity from metadata.

---

## A native desktop app

<p align="center">
  <img src="https://raw.githubusercontent.com/Fred78290/caker/main/images/home.png" alt="Caker home screen" width="32%" />
  <img src="https://raw.githubusercontent.com/Fred78290/caker/main/images/wizard.png" alt="Caker VM wizard" width="32%" />
  <img src="https://raw.githubusercontent.com/Fred78290/caker/main/images/settings.png" alt="Caker settings" width="32%" />
</p>

`Caker.app` is a SwiftUI application that follows macOS 26's Liquid Glass design, and it covers most of what the CLI does:

- **A creation wizard** with an image catalog picker, resources, shared folders, ports, sockets, and provisioning options and variables, including the Windows options (product key, display memory, automatic logon). During an unattended Linux or macOS install, the wizard shows the VM's screen live.
- **Mosaic or list view** of your VMs, with live screenshots, CPU and memory, and a detail pane.
- **Embedded VMs.** In app mode, VMs run inside Caker.app with no daemon required. You can also connect it to a local or remote `caked`.
- **Compose management**: a sidebar listing your projects with per-service status, a YAML editor that validates the file as you type, and Start/Stop from the menu bar.
- **An image cache browser** to create a VM from an image you have already downloaded, or to delete it.
- **A task list** of builds and provisions in progress on the daemon, which you can cancel.
- **Template recording** from the VM window's toolbar.
- **Automatic updates** with Sparkle (in the direct-download edition).

---

## Remote control and an LXD-compatible API

By default `cakectl` reaches the local daemon through a Unix socket. Start the daemon with `--tcp` and it also listens on the network, with TLS, so managing VMs on another Mac (a Mac mini in a closet, for instance) works the same as managing them locally:

```bash
# on the Mac mini
caked service listen --tcp

# on your laptop
cakectl --connect tcp://mac-mini.local:5101 list
```

Long-running operations (`build`, `launch`, `provision`) stream their progress back to the client. **Ctrl-C cancels the task on the server**, rather than just disconnecting from it. `cakectl tasks list` and `cakectl tasks cancel <id>` let you see and stop anything still running.

Start the daemon with `--rest`, and `caked` also exposes an **LXD-compatible REST API** (`/1.0/instances`, `/1.0/networks`, `/1.0/images`, `/1.0/operations`…), secured with mutual TLS. Existing LXD tooling can connect to it, and the **web UI** bundled with the app is served at `/ui`, so you can manage instances, images, networks, certificates and operations from a browser:

```bash
# install caked as a launchd service, with the REST API and web UI enabled
caked service install --rest

# or run it in the foreground
caked service listen --rest
```

---

## Two editions

Caker comes in two editions:

- **Direct download** from [GitHub Releases](https://github.com/Fred78290/caker/releases): every feature, with Sparkle automatic updates.
- **App Store edition**: runs inside the macOS App Sandbox. A few features can't work there because they need a short `sudo` helper, raw device access or a private setting: the Windows 11 installer, Compose DNS, the `169.254.169.254` IMDS alias, physical block devices, and resizing ASIF disks from the CLI. The app lists these limitations the first time it launches.

Both editions use the same engine, and IMDS itself still works in the sandboxed edition, on its gateway address.

---

## Under the hood

A few implementation details:

- **All Swift**: Swift Argument Parser for the CLIs, grpc-swift for the RPC layer, SwiftNIO for networking, port forwarding and SSH, Vapor for the REST API, and Apple's `Containerization` library for OCI and ext4 handling.
- **macOS 27 guests** install even where Apple's `VZMacOSInstaller` stalls (a known regression when installing macOS 27 on a macOS 26 host). For these guests, Caker uses an alternative restore path: it boots the VM in DFU mode and restores the IPSW through Apple's device-restore framework, much as Apple Configurator restores a physical Mac.
- **Windows guests, without wimlib.** Caker edits Windows' setup image (a `boot.wim` archive) with its own pure-Swift reader and writer, including a decoder for Microsoft's LZX compression. No `wimlib` or other external tool is needed on the Mac.
- **One process per VM.** Each running VM has its own service process, and a crash affects only that VM.
- **Disk conversion without external tools.** QCOW2 and VMDK images are converted to raw in pure Swift.

---

## Try it

- **Source and releases**: [github.com/Fred78290/caker](https://github.com/Fred78290/caker)
- **Documentation**: [caker.aldunelabs.com](https://caker.aldunelabs.com), with a command summary, a cheat sheet, and guides to Compose, provisioning and IMDS
- **In-guest agent**: [github.com/Fred78290/cakeagent](https://github.com/Fred78290/cakeagent)

Caker is released under the **AGPL-3.0** license. Issues, pull requests, and especially new PackerLite templates for distributions not yet covered are welcome.

If you try it, I would like to hear what you build with it, and what you think is still missing.

---

*Tags: macOS, Windows, Virtualization, Swift, DevOps, Developer Tools*
