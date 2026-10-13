# Caker.app: Running Linux and macOS Virtual Machines in a Native Mac App

*A tour of Caker's SwiftUI app, from creating a VM to running a multi-VM stack, without opening a terminal*

> 📸 **Screenshot 1 — Hero image.** *The main window in mosaic view with three or four VMs running (for example an Ubuntu desktop, a Fedora server and a macOS guest), so the live thumbnails are visible. Use the full window, sidebar included.*

---

Caker is an open-source toolchain for running virtual machines on macOS, built on Apple's Virtualization framework. It includes a daemon (`caked`) and a command-line client (`cakectl`), but this article is about the third piece: **Caker.app**, the desktop application.

The app does almost everything the command line does, through windows, sheets and menus. You can create a VM from a cloud image, an ISO or a macOS restore image, watch it install itself, open its display or a terminal, forward ports, share folders, and run several VMs together from a single YAML file. You never need to open Terminal, and if you do, the same VMs are available from `cakectl`.

Caker.app requires macOS 15 or later, and follows macOS 26's Liquid Glass design when it runs there. macOS guests require an Apple Silicon Mac.

---

## The main window

The main window has a sidebar with one entry per kind of object:

| Sidebar entry | What it shows |
| --- | --- |
| **Virtual machines** | Your VMs, with a live screenshot of each one |
| **Networks** | The virtual networks VMs can attach to |
| **Cloud images** | Image servers (simplestreams remotes) and the images they publish |
| **My templates** | Golden images you created from your own VMs |
| **Image cache** | Images you have already downloaded |
| **Compose** | Multi-VM projects defined in a `compose.yml` |
| **Tasks** | Long-running builds in progress, when the app is connected to a `caked` daemon |

The **Virtual machines** view has two layouts, selected from the toolbar.

**Mosaic** shows each VM as a tile with a live screenshot, its status, and its CPU, memory and disk. A single click selects a VM and a double-click opens it. The power button on each tile starts or stops it.

> 📸 **Screenshot 2 — Mosaic view.** *Close-up of two or three tiles: one running (live screenshot, green status), one stopped. Include the toolbar with the mosaic/list picker.*

**List** shows one row per VM, with a detail pane on the right: a large screenshot, the VM's resources, and buttons to open, start, stop, pause, duplicate, rename or delete it.

> 📸 **Screenshot 3 — List view with the detail pane.** *Select a running VM so the detail pane shows its screenshot and its CPU/memory/disk.*

Every VM also has a context menu with the same actions (Open, Start or Resume, Stop, Pause, Duplicate, Rename, Delete), in both layouts.

---

## Creating a virtual machine

**File → New virtual machine** opens a wizard with eight steps, shown as icons in the window's toolbar: **Name**, **Choose OS**, **CPU & Ram**, **Sharing**, **Disk**, **Network**, **Ports** and **Sockets**. Only the first two need your attention for a typical Linux VM; the others have sensible defaults.

### Choosing what to install

The **Choose OS** step is where you pick the image. Its source can be:

- **qcow2**: a cloud image, picked from a list of preconfigured releases (Ubuntu, Debian, Fedora, CentOS Stream, openSUSE, Alpine), or any image URL you paste
- **iso**: a Linux installer, from a list of preconfigured ISOs or your own
- **ipsw**: a macOS restore image, from macOS 12 to macOS 27 (Apple Silicon only)
- **oci**: an image stored in an OCI registry such as GitHub Container Registry
- **template**: one of your own templates
- **stream**: an image published by a simplestreams server, such as `ubuntu:noble`
- **raw**: an existing disk image on your Mac

> 📸 **Screenshot 4 — Wizard, "Choose OS" step.** *Show the image source picker and the "Preconfigured image" list open, with an Ubuntu or Fedora release selected.*

The same step holds the guest account: an **administrator name and password**, an optional **SSH public key**, and whether SSH accepts passwords. For cloud images, you can also attach your own **cloud-init user data** and **network configuration**.

### Resources and options

Each catalog image declares the minimum CPU and memory it needs, and the wizard applies them for you. A macOS 26 guest, for example, starts at 6 CPUs and 8 GiB of RAM. If you know what you are doing, the **Allow override minimum resources** toggle lets you go lower.

The **CPU & Ram** step also has the VM's options: **Autostart** (start the VM when Caker starts), **Dynamic forward ports**, **Refit display** (resize the guest display to fit the window), **Nested virtualization**, predictable network interface names, and **Suspendable** for macOS guests. You also set the display size here.

> 📸 **Screenshot 5 — Wizard, "CPU & Ram" step.** *Show the CPU and memory sliders and the Options section.*

The remaining steps are lists you fill in with **+**:

- **Sharing**: folders from your Mac, shared with the guest through Virtio-FS
- **Disk**: the root disk size and format (raw, or ASIF on macOS 26+), and extra disks
- **Network**: extra network interfaces (NAT, bridged, or a network you created)
- **Ports**: port forwarding from your Mac to the guest, Docker style (`8080:80/tcp`)
- **Sockets**: Unix sockets forwarded between your Mac and the guest

> 📸 **Screenshot 6 — Wizard, "Ports" step.** *A list with one or two forwarded ports and the "add" sheet open.*

---

## Installations that finish themselves

Installing an OS from an ISO or a restore image normally means clicking through dozens of screens. When the source is an **ipsw** or an **iso**, the wizard shows a toggle, **Configure automatically the system** or **Auto configuration with provisioning**, that does it for you.

Caker then installs the OS and drives the first boot itself. It reads the VM's screen with Apple's Vision framework, then types and clicks through Setup Assistant on macOS, or through the installer on Linux. It creates your account, waits for the network, and installs Caker's guest agent. Built-in templates cover macOS 12 to 27, Fedora, CentOS Stream, RHEL, openSUSE, Debian, Alpine and Ubuntu.

For a distribution without a built-in template, the wizard asks for a template file. A **Provisioning variables** editor below the image picker lets you define values the template can use, such as subscription credentials. Values whose name contains "password" are masked.

While this runs, **the wizard shows the VM's screen live**, so you can see each screen being filled in.

> 📸 **Screenshot 7 — Wizard during an unattended macOS install.** *The wizard's content area showing the VM's screen in the middle of Setup Assistant (for example the "Create a Mac Account" screen being filled in).*

If an installation fails, Caker keeps a short video of the run (`provision.mp4`, in the VM's folder) so you can see the screen it stopped on.

---

## The VM window

Double-clicking a VM opens it in its own window. The toolbar holds everything you need while the VM runs:

- A **status light**, and **Start**, **Stop** and **Resume** buttons. Hold **Option** while clicking Stop to force-stop the VM instead of asking the guest to shut down.
- **Pause** and **Restart**.
- **Create template**, to turn this VM into a reusable template.
- **Show cursor**, to show or hide your Mac's pointer over the VM.
- A **CPU usage graph**, once the guest agent is running.
- An **agent** button, to install or update Caker's guest agent.
- **Recovery mode**, for macOS guests.
- **Run hosted** or **Run detached**, to run the VM inside the app or in its own background process.
- **Settings** and **Delete**.

> 📸 **Screenshot 8 — VM window, display mode.** *A running Linux desktop (or a macOS guest) in its window, with the full toolbar visible, including the CPU graph.*

### Display or terminal

Once the guest agent is running, a segmented control lets you switch between the VM's **display** and a **terminal**. The terminal is a real shell in the guest, opened through the agent: there is no SSH to configure and no IP address to look up.

> 📸 **Screenshot 9 — VM window, terminal mode.** *The same VM switched to terminal mode, running a command such as `uname -a` or `htop`.*

A VM running in a separate process, or on another Mac, is displayed over VNC, and can send your Mac's clipboard to the guest.

### Changing a VM's settings

The **Settings** button opens a sheet with the same sections as the wizard: CPU count, memory, disk size, options, display size, forwarded ports, network attachments, directory sharing, extra disks and sockets.

> 📸 **Screenshot 10 — VM settings sheet.** *Scroll so the CPU/memory/disk section and the Forwarded ports and Directory sharing sections are visible.*

---

## Recording an installation as a template

If you need to automate an installer Caker has no template for, you can record one instead of writing it. On a running VM, click **Record** in the toolbar and go through the installer yourself. Caker saves your clicks and keystrokes as a template file (`.packerlite.yaml`) that the unattended installation can replay.

While recording, a **text recognition** toggle highlights every piece of text Caker can read on the VM's screen. With it on, a left click on a highlighted word is recorded as "click on this text", and a right click as "wait for this text to appear", rather than as screen coordinates. That makes the template work even when a screen appears at a different moment or position. A **Reset** button starts over, and for macOS guests a **VoiceOver** button records the accessibility shortcut that some Setup Assistant screens rely on.

> 📸 **Screenshot 11 — Recording with text recognition on.** *A VM window with the recording controls in the toolbar and blue highlights over the text of an installer screen.*

---

## Images and templates

**Cloud images** lists simplestreams servers, such as Ubuntu's. Selecting one shows the images it publishes, and **New Virtual Machine…** opens the wizard with that image already selected. The **+** button adds another server by URL.

> 📸 **Screenshot 12 — Cloud images.** *The Ubuntu remote selected, with its list of images and the detail pane.*

**Image cache** lists the images you have already downloaded: cloud images, ISOs, macOS restore images and OCI images. The **+** button creates a VM from the selected image without downloading it again, and **Delete** frees the disk space.

> 📸 **Screenshot 13 — Image cache.** *A few cached images of different types (qcow2, iso, ipsw), one selected.*

**My templates** lists the templates you created with **Create template**. From a template you can create a new VM or clone the template.

---

## Networks

Every VM gets a NAT interface by default. The **Networks** view lists the other networks available to VMs, and lets you create a **shared** network (VMs reach each other and the internet) or a **host** network (VMs reach your Mac and each other, but not the internet). For each one, you can set the DHCP range, netmask and lease time, and see how many VMs use it. **Start network** and **Stop network** are in the detail pane.

> 📸 **Screenshot 14 — Networks.** *A shared network selected, with its DHCP range and the "Used by" count in the detail pane.*

The interface used for **bridged** networking (a VM directly on your physical network) is chosen in **Settings → Advanced**.

---

## Compose: several VMs from one file

The **Compose** view manages groups of VMs described in a `compose.yml`, in the same format as Docker Compose. Each service runs as a full VM, and Caker adds fields for what a VM needs: disk size, packages to install, files to write and commands to run on first boot.

The **+** button opens the **Compose editor**, seeded with a working example: a MariaDB server and a phpMyAdmin web front end, in two VMs. The editor checks the YAML as you type and shows **Parses OK** or the error. **Add service** inserts a new service block for you, and **Save & Start** builds and starts the services in dependency order.

> 📸 **Screenshot 15 — Compose editor.** *The editor with the MariaDB + phpMyAdmin example and the green "Parses OK" indicator.*

The project then appears in the list, with a count of running services ("2/2 running"). Its detail pane shows each service's status and image.

> 📸 **Screenshot 16 — Compose project detail.** *A project with two running services in the detail pane.*

Services can reach each other by name: in the example, phpMyAdmin connects to `mariadb.myapp.compose.internal`. Any running VM, Compose or not, can be reached as `<vm-name>.compose.internal`. The domain can be changed in **Settings → Advanced**.

---

## Importing VMs from other apps

The **Import** menu brings in VMs from **Multipass**, **VMware**, **Tart**, **UTM** and **VirtualBuddy**. For Tart, UTM and VirtualBuddy, you can reference the existing disk instead of copying it.

> 📸 **Screenshot 17 — Import dialog.** *The import sheet for UTM or Tart, with a source VM selected.*

---

## Three ways to run VMs

Caker.app can work in three modes:

1. **Inside the app.** With no daemon installed, VMs run inside Caker.app itself. Nothing else is required.
2. **With a local daemon.** The **Service** menu installs `caked` as a background service, and starts or stops it. VMs then keep running when you quit the app, and are available from `cakectl` too.
3. **Connected to another Mac.** **Service → Connect to remote** opens a browser that lists the `caked` servers it finds on your local network (they announce themselves with Bonjour). You can also enter a server's address, port and optional password. The app then manages that Mac's VMs as if they were local, and the **Tasks** view shows the builds running there, which you can cancel.

> 📸 **Screenshot 18 — Service browser.** *The list of discovered servers, with the "Connect to a server…" sheet open (address, port, password, Use TLS).*

> 📸 **Screenshot 19 — Tasks.** *Two builds in progress, one selected, with its cancel button visible.*

---

## The menu bar

Caker also has a menu bar icon. Its menu lists every VM, with its own Start, Stop, Request stop, Suspend or Resume, Create template and Delete actions. It also lists your Compose projects (Open, Start, Stop), has a **New compose project…** item, and the same service controls as the Service menu. With the Dock icon hidden in Settings, Caker can run as a menu-bar-only app.

> 📸 **Screenshot 20 — Menu bar menu.** *The menu open on a VM's submenu, with the Compose submenu visible.*

---

## Settings

The Settings window has three tabs.

- **Application**: light, dark or system appearance; Dock and menu bar icons; and **Install command-line tools**, which makes `caked` and `cakectl` available from Terminal.
- **Virtual machines**: whether VMs launch inside the app, whether closing a VM's window shuts it down, screenshots, sending the clipboard to VMs over VNC, and the restore method used for macOS installs.
- **Advanced**: the bridged network interface, the Compose DNS domain, the default VM for `cakectl sh`/`exec`, the service pass-phrase, moving all VMs and images to another folder or disk (**Relocate…**, direct-download edition only), and an AWS-style metadata service (`169.254.169.254`) for Linux guests.

> 📸 **Screenshot 21 — Settings, Advanced tab.** *The Networking, Compose and Storage sections.*

---

## Direct download or App Store

Caker.app comes in two editions:

- **Direct download** from [GitHub Releases](https://github.com/Fred78290/caker/releases), with automatic updates.
- **App Store edition**, which runs in the macOS App Sandbox. A few features need privileges the sandbox does not allow: name resolution between VMs, the metadata service's `169.254.169.254` address, attaching physical disks, and resizing ASIF disks from the command line. The app lists them the first time it launches.

---

## Try it

- **Download and source code**: [github.com/Fred78290/caker](https://github.com/Fred78290/caker)
- **Documentation**: [caker.aldunelabs.com](https://caker.aldunelabs.com)

Caker is open source, under the AGPL-3.0 license. If you try the app, I would like to hear what works for you and what is missing: issues and pull requests are welcome on GitHub.

---

*Tags: macOS, Virtualization, SwiftUI, Mac Apps, Developer Tools*
