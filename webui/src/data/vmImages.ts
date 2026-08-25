// GENERATED FILE — DO NOT EDIT BY HAND.
// Source of truth: Sources/caker/Resources/VMImages.json (also read by VMImageCatalog.swift).
// Regenerate with `npm run sync-vm-images`.

export interface VMImageEntry {
  id: string
  label: string
  url: string
  minCPU?: number
  minMemoryMiB?: number
}

export interface VMImageCatalog {
  iso: VMImageEntry[]
  ipsw: VMImageEntry[]
  cloud: VMImageEntry[]
}

export const vmImages: Record<'arm64' | 'amd64', VMImageCatalog> = {
  "arm64": {
    "iso": [
      {
        "id": "ubuntu2604Desktop",
        "label": "Ubuntu 26.04 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/resolute/release/ubuntu-26.04-desktop-arm64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2604Server",
        "label": "Ubuntu 26.04 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/resolute/release/ubuntu-26.04-live-server-arm64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2404Desktop",
        "label": "Ubuntu 24.04.4 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/noble/release/ubuntu-24.04.4-desktop-arm64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2404Server",
        "label": "Ubuntu 24.04.4 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/noble/release/ubuntu-24.04.4-live-server-arm64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2204Desktop",
        "label": "Ubuntu 22.04.5 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/jammy/release/ubuntu-22.04.5-desktop-arm64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2204Server",
        "label": "Ubuntu 22.04.5 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/jammy/release/ubuntu-22.04.5-live-server-arm64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2004Desktop",
        "label": "Ubuntu 20.04.5 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/focal/release/ubuntu-20.04.5-desktop-arm64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2004Server",
        "label": "Ubuntu 20.04.5 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/focal/release/ubuntu-20.04.5-live-server-arm64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu1804Desktop",
        "label": "Ubuntu 18.04.6 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.6-desktop-arm64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu1804Server",
        "label": "Ubuntu 18.04.6 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.6-live-server-arm64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora44Desktop",
        "label": "Fedora 44 – Workstation",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Workstation/aarch64/iso/Fedora-Workstation-Live-44-1.7.aarch64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora44Server",
        "label": "Fedora 44 – Server",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Server/aarch64/iso/Fedora-Server-dvd-aarch64-44-1.7.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora43Desktop",
        "label": "Fedora 43 – Workstation",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/aarch64/iso/Fedora-Workstation-Live-43-1.6.aarch64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora43Server",
        "label": "Fedora 43 – Server",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/aarch64/iso/Fedora-Server-dvd-aarch64-43-1.6.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora42Desktop",
        "label": "Fedora 42 – Workstation",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Workstation/aarch64/iso/Fedora-Workstation-Live-42-1.1.aarch64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora42Server",
        "label": "Fedora 42 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Server/aarch64/iso/Fedora-Server-dvd-aarch64-42-1.1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora41Server",
        "label": "Fedora 41 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/41/Server/aarch64/iso/Fedora-Server-dvd-aarch64-41-1.4.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora40Desktop",
        "label": "Fedora 40 – Workstation",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Workstation/aarch64/iso/Fedora-Workstation-Live-osb-40-1.14.aarch64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora40Server",
        "label": "Fedora 40 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Server/aarch64/iso/Fedora-Server-dvd-aarch64-40-1.14.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos10",
        "label": "CentOS Stream 10",
        "url": "https://mirrors.centos.org/mirrorlist?path=/10-stream/BaseOS/aarch64/iso/CentOS-Stream-10-latest-aarch64-dvd1.iso&redirect=1&protocol=https",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos9",
        "label": "CentOS Stream 9",
        "url": "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/aarch64/iso/CentOS-Stream-9-latest-aarch64-dvd1.iso&redirect=1&protocol=https",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian1360",
        "label": "Debian 13.6.0 –",
        "url": "https://cdimage.debian.org/cdimage/release/current/arm64/iso-dvd/debian-13.6.0-arm64-DVD-1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap161",
        "label": "openSUSE Leap 16.1 – DVD",
        "url": "https://download.opensuse.org/distribution/leap/16.1/installer/iso/agama-installer.aarch64-Leap_16.1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap160",
        "label": "openSUSE Leap 16.0 – DVD",
        "url": "https://download.opensuse.org/distribution/leap/16.0/installer/iso/agama-installer.aarch64-Leap_16.0.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap156",
        "label": "openSUSE Leap 15.6 – DVD",
        "url": "https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-aarch64-Media.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap155",
        "label": "openSUSE Leap 15.5 – DVD",
        "url": "https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-aarch64-Media.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      }
    ],
    "ipsw": [
      {
        "id": "macos27_0",
        "label": "macOS 27.0",
        "url": "https://updates.cdn-apple.com/2026SummerSeed/7b1c2bd9-7617-426d-92e5-ef204407ffaa/UniversalMac_27.0_26A5416b_Restore.ipsw",
        "minCPU": 6,
        "minMemoryMiB": 8192
      },
      {
        "id": "macos26_6",
        "label": "macOS 26.6.2",
        "url": "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw",
        "minCPU": 6,
        "minMemoryMiB": 8192
      },
      {
        "id": "macos15_6_1",
        "label": "macOS 15.6.1",
        "url": "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-10809/CFD6DD38-DAF0-40DA-854F-31AAD1294C6F/UniversalMac_15.6.1_24G90_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos14_6_1",
        "label": "macOS 14.6.1",
        "url": "https://updates.cdn-apple.com/2024SummerFCS/fullrestores/062-52859/932E0A8F-6644-4759-82DA-F8FA8DEA806A/UniversalMac_14.6.1_23G93_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos13_6",
        "label": "macOS 13.6",
        "url": "https://updates.cdn-apple.com/2023FallFCS/fullrestores/042-55833/C0830847-A2F8-458F-B680-967991820931/UniversalMac_13.6_22G120_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos12_6_1",
        "label": "macOS 12.6.1",
        "url": "https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-66032/8D8D90C6-A876-4FFF-BBF4-D158939B3841/UniversalMac_12.6.1_21G217_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      }
    ],
    "cloud": [
      {
        "id": "ubuntu2604LTS",
        "label": "Ubuntu 26.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-arm64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2504LTS",
        "label": "Ubuntu 25.04",
        "url": "https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-arm64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2404LTS",
        "label": "Ubuntu 24.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2204LTS",
        "label": "Ubuntu 22.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-arm64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2004LTS",
        "label": "Ubuntu 20.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-arm64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian14",
        "label": "Debian 14 generic cloud (forky)",
        "url": "https://cloud.debian.org/images/cloud/forky/daily/latest/debian-14-genericcloud-arm64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian13",
        "label": "Debian 13 generic cloud (trixie)",
        "url": "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-arm64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian12",
        "label": "Debian 12 generic cloud (bookworm)",
        "url": "https://cloud.debian.org/images/cloud/bookworm/daily/latest/debian-12-genericcloud-arm64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian11",
        "label": "Debian 11 generic cloud (bullseye)",
        "url": "https://cloud.debian.org/images/cloud/bullseye/daily/latest/debian-11-genericcloud-amd64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos10",
        "label": "CentOS 10",
        "url": "https://cloud.centos.org/centos/10-stream/aarch64/images/CentOS-Stream-GenericCloud-10-latest.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos9",
        "label": "CentOS 9",
        "url": "https://cloud.centos.org/centos/9-stream/aarch64/images/CentOS-Stream-GenericCloud-9-latest.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora44",
        "label": "Fedora 44",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Server/aarch64/images/Fedora-Server-Guest-Generic-44-1.7.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora43",
        "label": "Fedora 43",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/aarch64/images/Fedora-Server-Guest-Generic-43-1.6.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora42",
        "label": "Fedora 42",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Server/aarch64/images/Fedora-Server-Guest-Generic-42-1.1.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora41",
        "label": "Fedora 41",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/41/Server/aarch64/images/Fedora-Server-KVM-41-1.4.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora40",
        "label": "Fedora 40",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Server/aarch64/images/Fedora-Server-KVM-40-1.14.aarch64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE156",
        "label": "OpenSUSE Leap 15.6",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.aarch64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE155",
        "label": "OpenSUSE Leap 15.5",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.aarch64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE154",
        "label": "OpenSUSE Leap 15.4",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.aarch64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine322",
        "label": "Alpine 3.22",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/generic_alpine-3.22.1-aarch64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine321",
        "label": "Alpine 3.21",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-aarch64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine320",
        "label": "Alpine 3.20",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/generic_alpine-3.20.7-aarch64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      }
    ]
  },
  "amd64": {
    "iso": [
      {
        "id": "ubuntu2604Desktop",
        "label": "Ubuntu 26.04 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/resolute/release/ubuntu-26.04-desktop-amd64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2604Server",
        "label": "Ubuntu 26.04 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/resolute/release/ubuntu-26.04-live-server-amd64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2404Desktop",
        "label": "Ubuntu 24.04.4 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/noble/release/ubuntu-24.04.4-desktop-amd64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2404Server",
        "label": "Ubuntu 24.04.4 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/noble/release/ubuntu-24.04.4-live-server-amd64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2204Desktop",
        "label": "Ubuntu 22.04.5 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/jammy/release/ubuntu-22.04.5-desktop-amd64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2204Server",
        "label": "Ubuntu 22.04.5 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/jammy/release/ubuntu-22.04.5-live-server-amd64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2004Desktop",
        "label": "Ubuntu 20.04.5 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/focal/release/ubuntu-20.04.5-desktop-amd64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu2004Server",
        "label": "Ubuntu 20.04.5 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/focal/release/ubuntu-20.04.5-live-server-amd64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu1804Desktop",
        "label": "Ubuntu 18.04.6 LTS – Desktop",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.6-desktop-amd64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "ubuntu1804Server",
        "label": "Ubuntu 18.04.6 LTS – Server",
        "url": "https://cdimage.ubuntu.com/ubuntu/releases/bionic/release/ubuntu-18.04.6-live-server-amd64.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian1360",
        "label": "Debian 13.6.0 –",
        "url": "https://cdimage.debian.org/cdimage/release/current/amd64/iso-dvd/debian-13.6.0-amd64-DVD-1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora44Desktop",
        "label": "Fedora 44 – Workstation",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Workstation/x86_64/iso/Fedora-Workstation-Live-44-1.7.x86_64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora44Server",
        "label": "Fedora 44 – Server",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Server/x86_64/iso/Fedora-Server-dvd-x86_64-44-1.7.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora43Desktop",
        "label": "Fedora 43 – Workstation",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/x86_64/iso/Fedora-Workstation-Live-43-1.6.x86_64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora43Server",
        "label": "Fedora 43 – Server",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/x86_64/iso/Fedora-Server-dvd-x86_64-43-1.6.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora42Desktop",
        "label": "Fedora 42 – Workstation",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Workstation/x86_64/iso/Fedora-Workstation-Live-42-1.1.x86_64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora42Server",
        "label": "Fedora 42 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Server/x86_64/iso/Fedora-Server-dvd-x86_64-42-1.1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora41Desktop",
        "label": "Fedora 41 – Workstation",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.4.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora41Server",
        "label": "Fedora 41 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-dvd-x86_64-41-1.4.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora40Desktop",
        "label": "Fedora 40 – Workstation",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-osb-40-1.14.x86_64.iso",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "fedora40Server",
        "label": "Fedora 40 – Server",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Server/x86_64/iso/Fedora-Server-dvd-x86_64-40-1.14.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos10",
        "label": "CentOS Stream 10 – DVD",
        "url": "https://mirrors.centos.org/mirrorlist?path=/10-stream/BaseOS/x86_64/iso/CentOS-Stream-10-latest-x86_64-dvd1.iso&redirect=1&protocol=https",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos9",
        "label": "CentOS Stream 9 – DVD",
        "url": "https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap161",
        "label": "openSUSE Leap 16.1",
        "url": "https://download.opensuse.org/distribution/leap/16.1/installer/iso/agama-installer.x86_64-Leap_16.1.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap160",
        "label": "openSUSE Leap 16.0",
        "url": "https://download.opensuse.org/distribution/leap/16.0/installer/iso/agama-installer.x86_64-Leap_16.0.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap156",
        "label": "openSUSE Leap 15.6",
        "url": "https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSELeap155",
        "label": "openSUSE Leap 15.5",
        "url": "https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso",
        "minCPU": 2,
        "minMemoryMiB": 2048
      }
    ],
    "ipsw": [
      {
        "id": "macos27_0",
        "label": "macOS 27.0",
        "url": "https://updates.cdn-apple.com/2026SummerSeed/7b1c2bd9-7617-426d-92e5-ef204407ffaa/UniversalMac_27.0_26A5416b_Restore.ipsw",
        "minCPU": 6,
        "minMemoryMiB": 8192
      },
      {
        "id": "macos26_6",
        "label": "macOS 26.6.2",
        "url": "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw",
        "minCPU": 6,
        "minMemoryMiB": 8192
      },
      {
        "id": "macos15_6_1",
        "label": "macOS 15.6.1",
        "url": "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-10809/CFD6DD38-DAF0-40DA-854F-31AAD1294C6F/UniversalMac_15.6.1_24G90_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos14_6_1",
        "label": "macOS 14.6.1",
        "url": "https://updates.cdn-apple.com/2024SummerFCS/fullrestores/062-52859/932E0A8F-6644-4759-82DA-F8FA8DEA806A/UniversalMac_14.6.1_23G93_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos13_6",
        "label": "macOS 13.6",
        "url": "https://updates.cdn-apple.com/2023FallFCS/fullrestores/042-55833/C0830847-A2F8-458F-B680-967991820931/UniversalMac_13.6_22G120_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      },
      {
        "id": "macos12_6_1",
        "label": "macOS 12.6.1",
        "url": "https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-66032/8D8D90C6-A876-4FFF-BBF4-D158939B3841/UniversalMac_12.6.1_21G217_Restore.ipsw",
        "minCPU": 4,
        "minMemoryMiB": 4096
      }
    ],
    "cloud": [
      {
        "id": "ubuntu2604LTS",
        "label": "Ubuntu 26.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2504LTS",
        "label": "Ubuntu 25.04",
        "url": "https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-amd64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2404LTS",
        "label": "Ubuntu 24.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2204LTS",
        "label": "Ubuntu 22.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "ubuntu2004LTS",
        "label": "Ubuntu 20.04 LTS",
        "url": "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian14",
        "label": "Debian 14 generic cloud (forky)",
        "url": "https://cloud.debian.org/images/cloud/forky/daily/latest/debian-14-genericcloud-amd64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian13",
        "label": "Debian 13 generic cloud (trixie)",
        "url": "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian12",
        "label": "Debian 12 generic cloud (bookworm)",
        "url": "https://cloud.debian.org/images/cloud/bookworm/daily/latest/debian-12-genericcloud-amd64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "debian11",
        "label": "Debian 11 generic cloud (bullseye)",
        "url": "https://cloud.debian.org/images/cloud/bullseye/daily/latest/debian-11-genericcloud-amd64-daily.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos10",
        "label": "CentOS 10",
        "url": "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "centos9",
        "label": "CentOS 9",
        "url": "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora44",
        "label": "Fedora 44",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Server/x86_64/images/Fedora-Server-Guest-Generic-44-1.7.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora43",
        "label": "Fedora 43",
        "url": "https://download.fedoraproject.org/pub/fedora/linux/releases/43/Server/x86_64/images/Fedora-Server-Guest-Generic-43-1.6.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora42",
        "label": "Fedora 42",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/42/Server/x86_64/images/Fedora-Server-Guest-Generic-42-1.1.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora41",
        "label": "Fedora 41",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/41/Server/x86_64/images/Fedora-Server-KVM-41-1.4.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "fedora40",
        "label": "Fedora 40",
        "url": "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Server/x86_64/images/Fedora-Server-KVM-40-1.14.x86_64.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE156",
        "label": "OpenSUSE Leap 15.6",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.x86_64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE155",
        "label": "OpenSUSE Leap 15.5",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.x86_64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "openSUSE154",
        "label": "OpenSUSE Leap 15.4",
        "url": "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.x86_64-NoCloud.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine322",
        "label": "Alpine 3.22",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/generic_alpine-3.22.1-x86_64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine321",
        "label": "Alpine 3.21",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-x86_64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      },
      {
        "id": "alpine320",
        "label": "Alpine 3.20",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/generic_alpine-3.20.7-x86_64-uefi-cloudinit-r0.qcow2",
        "minCPU": 2,
        "minMemoryMiB": 2048
      }
    ]
  }
}
