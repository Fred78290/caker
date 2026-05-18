import { Modal } from 'bootstrap';
import { useEffect, useRef, useState } from 'react';
import { createInstance } from '../api/instances';
import { listNetworks } from '../api/networks';
import { getOperation } from '../api/operations';
import { getServerInfo } from '../api/server';
import { Spinner } from '../components/Spinner';
import type { LXDNetwork } from '../types/lxd';

interface Props {
  onCreated: () => void
  initialAlias?: string
  onClose?: () => void
}

interface NetworkInterfaceItem {
  network: string
  device: string
}

interface OperationLogItem {
  at: string
  description: string
}

const DEFAULT_NAT_NETWORK_NAME = 'nat'

const DEVICE_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_.-]*$/
const FORWARDED_PORT_PATTERN = /^(\d{1,5}):(\d{1,5})\/(tcp|udp|both)$/i
const VM_NAME_ADJECTIVES = ['swift', 'brave', 'calm', 'silent', 'lucky', 'rapid', 'crisp', 'frosty']
const VM_NAME_NOUNS = ['otter', 'falcon', 'cedar', 'pine', 'ember', 'comet', 'delta', 'harbor']
const DEFAULT_IMAGE_ALIAS = 'ubuntu:26.04'

const UBUNTU_ISO_BASE = 'https://cdimage.ubuntu.com/ubuntu/releases'
const UBUNTU_CLOUD_BASE = 'https://cloud-images.ubuntu.com/releases'
const CENTOS_ISO_BASE = 'https://mirror.centos.org/centos/9-stream/BaseOS'
const CENTOS_CLOUD_BASE = 'https://cloud.centos.org/centos'
const FEDORA_ISO_BASE = 'https://download.fedoraproject.org/pub/fedora/linux/releases'
const FEDORA_CLOUD_BASE = 'https://download.fedoraproject.org/pub/fedora/linux/releases'
const DEBIAN_CLOUD_BASE = 'https://cloud.debian.org/images/cloud'
const OPENSUSE_CLOUD_BASE = 'https://download.opensuse.org/repositories/Cloud:/Images:/Leap'
const ALPINE_CLOUD_BASE = 'https://dl-cdn.alpinelinux.org/alpine'
const MACOS_1561_IPSW_URL = 'https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-10809/CFD6DD38-DAF0-40DA-854F-31AAD1294C6F/UniversalMac_15.6.1_24G90_Restore.ipsw'
const MACOS_265_IPSW_URL = 'https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-58869/DFB1CEEF-5619-4591-9924-E20DB2C8FED0/UniversalMac_26.5_25F71_Restore.ipsw'
const MACOS_1461_IPSW_URL = 'https://updates.cdn-apple.com/2024SummerFCS/fullrestores/062-52859/932E0A8F-6644-4759-82DA-F8FA8DEA806A/UniversalMac_14.6.1_23G93_Restore.ipsw'
const MACOS_136_IPSW_URL = 'https://updates.cdn-apple.com/2023FallFCS/fullrestores/042-55833/C0830847-A2F8-458F-B680-967991820931/UniversalMac_13.6_22G120_Restore.ipsw'

const LXD_TO_UBUNTU_ARCH: Record<string, string> = {
  x86_64: 'amd64',
  aarch64: 'arm64',
  arm64: 'arm64',
  armv7l: 'armhf',
  ppc64le: 'ppc64el',
  s390x: 's390x',
  riscv64: 'riscv64',
}

const LXD_TO_GENERIC_ARCH: Record<string, string> = {
  x86_64: 'x86_64',
  aarch64: 'aarch64',
  arm64: 'aarch64',
  armv7l: 'armhfp',
  ppc64le: 'ppc64le',
  s390x: 's390x',
}

const buildSourceImages = (lxdArch: string, iso: boolean): { label: string; url: string }[] => {
  const ubuntuArch = LXD_TO_UBUNTU_ARCH[lxdArch] ?? 'amd64'
  const genericArch = LXD_TO_GENERIC_ARCH[lxdArch] ?? 'x86_64'
  
  if (iso) {
  return [
    // Ubuntu ISOs
    { label: `Ubuntu 26.04 LTS – Server ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/resolute/release/ubuntu-26.04-live-server-${ubuntuArch}.iso` },
    { label: `Ubuntu 26.04 LTS – Desktop ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/resolute/release/ubuntu-26.04-desktop-${ubuntuArch}.iso` },
    { label: `Ubuntu 24.04.4 LTS – Server ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/noble/release/ubuntu-24.04.4-live-server-${ubuntuArch}.iso` },
    { label: `Ubuntu 24.04.4 LTS – Desktop ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/noble/release/ubuntu-24.04.4-desktop-${ubuntuArch}.iso` },
    { label: `Ubuntu 22.04.5 LTS – Server ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/jammy/release/ubuntu-22.04.5-live-server-${ubuntuArch}.iso` },
    { label: `Ubuntu 22.04.5 LTS – Desktop ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/jammy/release/ubuntu-22.04.5-desktop-${ubuntuArch}.iso` },
    { label: `Ubuntu 20.04.5 LTS – Server ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/focal/release/ubuntu-20.04.5-live-server-${ubuntuArch}.iso` },
    { label: `Ubuntu 20.04.5 LTS – Desktop ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/focal/release/ubuntu-20.04.5-desktop-${ubuntuArch}.iso` },
    { label: `Ubuntu 18.04.6 LTS – Server ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/bionic/release/ubuntu-18.04.6-live-server-${ubuntuArch}.iso` },
    { label: `Ubuntu 18.04.6 LTS – Desktop ISO (${ubuntuArch})`, url: `${UBUNTU_ISO_BASE}/bionic/release/ubuntu-18.04.6-desktop-${ubuntuArch}.iso` },
    { label: `CentOS Stream 10 – DVD ISO (${genericArch})`, url: `https://mirror.stream.centos.org/10-stream/BaseOS/${genericArch}/iso/CentOS-Stream-10-latest-${genericArch}-dvd1.iso` },
    { label: `CentOS Stream 9 – DVD ISO (${genericArch})`, url: `${CENTOS_ISO_BASE}/${genericArch}/iso/CentOS-Stream-9-latest-${genericArch}-dvd.iso` },
    // Fedora ISOs
    { label: `Fedora 42 – Server ISO (${genericArch})`, url: `${FEDORA_ISO_BASE}/42/Server/${genericArch}/iso/Fedora-Server-dvd-${genericArch}-42-1.1.iso` },
    { label: `Fedora 41 – Server ISO (${genericArch})`, url: `${FEDORA_ISO_BASE}/41/Server/${genericArch}/iso/Fedora-Server-dvd-${genericArch}-41-1.4.iso` },
    { label: `Fedora 40 – Server ISO (${genericArch})`, url: `${FEDORA_ISO_BASE}/40/Server/${genericArch}/iso/Fedora-Server-dvd-${genericArch}-40-1.14.iso` },
  ]
  } else {
  return [
    // Ubuntu Cloud Images
    { label: `Ubuntu 26.04 LTS – Cloud Image (${ubuntuArch})`, url: `${UBUNTU_CLOUD_BASE}/resolute/release/ubuntu-26.04-server-cloudimg-${ubuntuArch}.img` },
    { label: `Ubuntu 25.04 – Cloud Image (${ubuntuArch})`, url: `${UBUNTU_CLOUD_BASE}/plucky/release/ubuntu-25.04-server-cloudimg-${ubuntuArch}.img` },
    { label: `Ubuntu 24.04 LTS – Cloud Image (${ubuntuArch})`, url: `${UBUNTU_CLOUD_BASE}/noble/release/ubuntu-24.04-server-cloudimg-${ubuntuArch}.img` },
    { label: `Ubuntu 22.04 LTS – Cloud Image (${ubuntuArch})`, url: `${UBUNTU_CLOUD_BASE}/jammy/release/ubuntu-22.04-server-cloudimg-${ubuntuArch}.img` },
    { label: `Ubuntu 20.04 LTS – Cloud Image (${ubuntuArch})`, url: `${UBUNTU_CLOUD_BASE}/focal/release/ubuntu-20.04-server-cloudimg-${ubuntuArch}.img` },
    
    // CentOS Cloud Images
    { label: `CentOS Stream 10 – Cloud (${genericArch})`, url: `${CENTOS_CLOUD_BASE}/10-stream/${genericArch}/images/CentOS-Stream-GenericCloud-10-20250506.2.${genericArch}.qcow2` },
    { label: `CentOS Stream 9 – Cloud (${genericArch})`, url: `${CENTOS_CLOUD_BASE}/9-stream/${genericArch}/images/CentOS-Stream-GenericCloud-9-20250526.1.${genericArch}.qcow2` },
    
    // Fedora Cloud Images
    { label: `Fedora 42 – Cloud (${genericArch})`, url: `${FEDORA_CLOUD_BASE}/42/Server/${genericArch}/images/Fedora-Server-Guest-Generic-42-1.1.${genericArch}.qcow2` },
    { label: `Fedora 41 – Cloud (${genericArch})`, url: `${FEDORA_CLOUD_BASE}/41/Server/${genericArch}/images/Fedora-Server-KVM-41-1.4.${genericArch}.qcow2` },
    { label: `Fedora 40 – Cloud (${genericArch})`, url: `${FEDORA_CLOUD_BASE}/40/Server/${genericArch}/images/Fedora-Server-KVM-40-1.14.${genericArch}.qcow2` },
    
    // Debian Cloud Images
    { label: `Debian 12 (Bookworm) – Cloud (${genericArch})`, url: `${DEBIAN_CLOUD_BASE}/bookworm/latest/debian-12-generic-${genericArch}.qcow2` },
    { label: `Debian 11 (Bullseye) – Cloud (${genericArch})`, url: `${DEBIAN_CLOUD_BASE}/bullseye/latest/debian-11-generic-${genericArch}.qcow2` },
    { label: `Debian 10 (Buster) – Cloud (${genericArch})`, url: `${DEBIAN_CLOUD_BASE}/buster/latest/debian-10-generic-${genericArch}.qcow2` },
    
    // openSUSE Cloud Images
    { label: `openSUSE Leap 15.6 – Cloud (${genericArch})`, url: `${OPENSUSE_CLOUD_BASE}_15.6/images/openSUSE-Leap-15.6.${genericArch}-NoCloud.qcow2` },
    { label: `openSUSE Leap 15.5 – Cloud (${genericArch})`, url: `${OPENSUSE_CLOUD_BASE}_15.5/images/openSUSE-Leap-15.5.${genericArch}-NoCloud.qcow2` },
    { label: `openSUSE Leap 15.4 – Cloud (${genericArch})`, url: `${OPENSUSE_CLOUD_BASE}_15.4/images/openSUSE-Leap-15.4.${genericArch}-NoCloud.qcow2` },
    
    // Alpine Cloud Images
    { label: `Alpine 3.22 – Cloud (${genericArch})`, url: `${ALPINE_CLOUD_BASE}/v3.22/releases/cloud/generic_alpine-3.22.1-${genericArch}-uefi-cloudinit-r0.qcow2` },
    { label: `Alpine 3.21 – Cloud (${genericArch})`, url: `${ALPINE_CLOUD_BASE}/v3.21/releases/cloud/generic_alpine-3.21.2-${genericArch}-uefi-cloudinit-r0.qcow2` },
    { label: `Alpine 3.20 – Cloud (${genericArch})`, url: `${ALPINE_CLOUD_BASE}/v3.20/releases/cloud/generic_alpine-3.20.7-${genericArch}-uefi-cloudinit-r0.qcow2` },
  ]
  }
}

const buildMacosIpswSources = (lxdArch: string): { label: string; url: string }[] => {
  const isArm64Server = lxdArch === 'aarch64' || lxdArch === 'arm64'
  if (!isArm64Server) return []

  return [
    { label: 'macOS 26.5 – IPSW (Apple Silicon)', url: MACOS_265_IPSW_URL },
    { label: 'macOS 15.6.1 – IPSW (Apple Silicon)', url: MACOS_1561_IPSW_URL },
    { label: 'macOS 14.6.1 – IPSW (Apple Silicon)', url: MACOS_1461_IPSW_URL },
    { label: 'macOS 13.6 – IPSW (Apple Silicon)', url: MACOS_136_IPSW_URL },
  ]
}

const isAutoInstallAllowed = (value: string) => {
  const v = value.toLowerCase().trim()
  if (!v.startsWith('iso://') && !v.endsWith('.iso')) return false
  return v.includes('ubuntu')
}

const generateRandomVmName = () => {
  const adjective = VM_NAME_ADJECTIVES[Math.floor(Math.random() * VM_NAME_ADJECTIVES.length)]
  const noun = VM_NAME_NOUNS[Math.floor(Math.random() * VM_NAME_NOUNS.length)]
  const suffix = Math.floor(100 + Math.random() * 900)
  return `${adjective}-${noun}-${suffix}`
}

const suggestVmNameFromAlias = (value: string) => {
  const alias = value.trim()
  if (!alias) return generateRandomVmName()

  const withoutRemote = alias.includes(':') ? alias.split(':').slice(1).join(':') : alias
  const firstSegment = withoutRemote.split('/').filter(Boolean).slice(-1)[0] ?? withoutRemote
  const normalized = firstSegment
    .toLowerCase()
    .replace(/[^a-z0-9.-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '')

  const base = normalized || 'vm'
  const prefix = generateRandomVmName()
  // const suffix = Math.floor(100 + Math.random() * 900)
  return `${prefix}-${base}`
}

const parseProgressPercent = (value: string | null) => {
  if (!value) return null
  const match = value.match(/(\d{1,3})\s*%/)
  if (!match) return null

  const progress = Number.parseInt(match[1], 10)
  if (!Number.isFinite(progress) || progress < 0 || progress > 100) return null
  return progress
}

const cleanupModalArtifacts = () => {
  document.querySelectorAll('.modal-backdrop').forEach((element) => {
    element.remove()
  })
  document.body.classList.remove('modal-open')
  document.body.style.removeProperty('overflow')
  document.body.style.removeProperty('padding-right')
}

export function CreateInstanceModal({ onCreated, initialAlias, onClose }: Props) {
  const closeNotifiedRef = useRef(false)
  const sourceAlias = initialAlias?.trim() || ''
  const hasSourceContext = sourceAlias.length > 0

  const getInitialAlias = () => initialAlias?.trim() || DEFAULT_IMAGE_ALIAS

  const [activeTab, setActiveTab] = useState<'general' | 'system' | 'access' | 'network'>('general')
  const [name, setName] = useState(generateRandomVmName())
  const [nameEdited, setNameEdited] = useState(false)
  const [alias, setAlias] = useState(getInitialAlias())
  const [type, setType] = useState<'virtual-machine' | 'container'>('virtual-machine')
  const [description, setDescription] = useState('')
  const [cpu, setCpu] = useState('2')
  const [memoryMB, setMemoryMB] = useState('2048')
  const [diskGB, setDiskGB] = useState('20')
  const [user, setUser] = useState('admin')
  const [password, setPassword] = useState('')
  const [clearPassword, setClearPassword] = useState(false)
  const [mainGroup, setMainGroup] = useState('adm')
  const [otherGroups, setOtherGroups] = useState('sudo')
  const [sshAuthorizedKey, setSshAuthorizedKey] = useState('')
  const [forwardedPorts, setForwardedPorts] = useState('')
  const [netIfnames, setNetIfnames] = useState(true)
  const [autostart, setAutostart] = useState(false)
  const [bridgedNetwork, setBridgedNetwork] = useState(false)
  const [nested, setNested] = useState(false)
  const [dynamicPortForwarding, setDynamicPortForwarding] = useState(false)
  const [enableConsole, setEnableConsole] = useState(true)
  const [autoinstall, setAutoinstall] = useState(() => isAutoInstallAllowed(initialAlias?.trim() || DEFAULT_IMAGE_ALIAS))
  const [networks, setNetworks] = useState('')
  const [availableNetworks, setAvailableNetworks] = useState<LXDNetwork[]>([])
  const [networkInterfaces, setNetworkInterfaces] = useState<NetworkInterfaceItem[]>([])
  const [selectedNetwork, setSelectedNetwork] = useState('')
  const [loadingNetworks, setLoadingNetworks] = useState(false)
  const [serverArch, setServerArch] = useState('amd64')
  const [networkLoadError, setNetworkLoadError] = useState<string | null>(null)
  const [networkInterfacesError, setNetworkInterfacesError] = useState<string | null>(null)
  const [forwardedPortsError, setForwardedPortsError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [activeOperationId, setActiveOperationId] = useState<string | null>(null)
  const [operationDescription, setOperationDescription] = useState<string | null>(null)
  const [operationStatus, setOperationStatus] = useState<string | null>(null)
  const [operationLog, setOperationLog] = useState<OperationLogItem[]>([])
  const [error, setError] = useState<string | null>(null)

  function defaultDeviceName(index: number, useNetIfnames: boolean = netIfnames) {
    return useNetIfnames ? `eth${index}` : `enp0s${index}`
  }

  function buildNetworkConfig(items: NetworkInterfaceItem[]) {
    if (items.length === 0) return ''

    const lines: string[] = ['#cloud-config', 'network:', '  version: 2', '  ethernets:']

    items.forEach((item) => {
      lines.push(`    ${item.device}:`)
      lines.push(`      # caker-network: ${item.network}`)
      lines.push('      dhcp4: true')
      lines.push('      dhcp6: true')
    })

    return lines.join('\n')
  }

  function syncInterfacesToConfig(items: NetworkInterfaceItem[]) {
    setNetworkInterfaces(items)
    setNetworks(buildNetworkConfig(items))
  }

  function findDefaultNatNetwork(items: LXDNetwork[]) {
    const managedNat = items.find((item) => item.managed && item.type === 'nat')

    if (managedNat) return managedNat

    const lxdbr0 = items.find((item) => item.name === DEFAULT_NAT_NETWORK_NAME)
    if (lxdbr0) return lxdbr0

    return items.find((item) => item.managed && item.type === 'nat') ?? null
  }

  function buildDefaultNetworkInterfaces(items: LXDNetwork[], useNetIfnames: boolean = netIfnames): NetworkInterfaceItem[] {
    const nat = findDefaultNatNetwork(items)
    if (!nat) return []

    return [{ network: nat.name, device: defaultDeviceName(0, useNetIfnames) }]
  }

  const resetForm = (nextAlias: string = getInitialAlias()) => {
    setActiveTab('general')
    setName(generateRandomVmName())
    setNameEdited(false)
    setAlias(nextAlias)
    setType('virtual-machine')
    setDescription('')
    setCpu('2')
    setMemoryMB('2048')
    setDiskGB('20')
    setUser('admin')
    setPassword('')
    setClearPassword(false)
    setMainGroup('adm')
    setOtherGroups('sudo')
    setSshAuthorizedKey('')
    setForwardedPorts('')
    setForwardedPortsError(null)
    setNetIfnames(true)
    setAutostart(false)
    setBridgedNetwork(false)
    setNested(false)
    setDynamicPortForwarding(false)
    setEnableConsole(false)
    setAutoinstall(isAutoInstallAllowed(nextAlias))
    const defaultInterfaces = buildDefaultNetworkInterfaces(availableNetworks, true)
    syncInterfacesToConfig(defaultInterfaces)
    setSelectedNetwork(defaultInterfaces[0]?.network ?? availableNetworks[0]?.name ?? '')
    setNetworkInterfacesError(null)
    setError(null)
    setBusy(false)
    setActiveOperationId(null)
    setOperationDescription(null)
    setOperationStatus(null)
    setOperationLog([])
  }

  const handleClose = () => {
    if (closeNotifiedRef.current) return
    closeNotifiedRef.current = true
    onClose?.()
  }

  const hasDuplicateDevice = (items: NetworkInterfaceItem[]) => {
    const names = items.map((item) => item.device.trim().toLowerCase()).filter(Boolean)
    return new Set(names).size !== names.length
  }

  const hasInvalidDeviceName = (items: NetworkInterfaceItem[]) =>
    items.some((item) => !DEVICE_NAME_PATTERN.test(item.device.trim()))

  const splitForwardedPorts = (value: string) =>
    value
      .split(/[,\n]/)
      .map((item) => item.trim())
      .filter(Boolean)

  const findInvalidForwardedPorts = (items: string[]) =>
    items.filter((item) => {
      const match = item.match(FORWARDED_PORT_PATTERN)
      if (!match) return true

      const hostPort = Number.parseInt(match[1], 10)
      const guestPort = Number.parseInt(match[2], 10)
      return hostPort < 1 || hostPort > 65535 || guestPort < 1 || guestPort > 65535
    })

  const updateForwardedPorts = (value: string) => {
    setForwardedPorts(value)

    const values = splitForwardedPorts(value)
    const invalid = findInvalidForwardedPorts(values)
    if (invalid.length > 0) {
      setForwardedPortsError('Forwarded ports must match host:guest/(tcp|udp|both) with ports between 1 and 65535')
      return
    }

    setForwardedPortsError(null)
  }

  const addNetworkInterface = () => {
    if (!selectedNetwork) return

    if (networkInterfaces.some((item) => item.network === selectedNetwork)) {
      setNetworkInterfacesError(`Network \"${selectedNetwork}\" is already added`)
      return
    }

    const next: NetworkInterfaceItem[] = [
      ...networkInterfaces,
      { network: selectedNetwork, device: defaultDeviceName(networkInterfaces.length) },
    ]
    setNetworkInterfacesError(null)
    syncInterfacesToConfig(next)
  }

  const removeNetworkInterface = (index: number) => {
    const next = networkInterfaces
      .filter((_, i) => i !== index)
      .map((item, i) => ({ ...item, device: defaultDeviceName(i) }))

    if (hasDuplicateDevice(next)) {
      setNetworkInterfacesError('Device names must be unique')
    } else if (hasInvalidDeviceName(next)) {
      setNetworkInterfacesError('Device names must start with a letter and contain only letters, digits, _, . or -')
    } else {
      setNetworkInterfacesError(null)
    }
    syncInterfacesToConfig(next)
  }

  const updateInterfaceDevice = (index: number, device: string) => {
    const value = device.trim()
    const next = networkInterfaces.map((item, i) => (i === index ? { ...item, device: value || defaultDeviceName(index) } : item))

    if (hasDuplicateDevice(next)) {
      setNetworkInterfacesError('Device names must be unique')
    } else if (hasInvalidDeviceName(next)) {
      setNetworkInterfacesError('Device names must start with a letter and contain only letters, digits, _, . or -')
    } else {
      setNetworkInterfacesError(null)
    }

    syncInterfacesToConfig(next)
  }

  useEffect(() => {
    getServerInfo()
      .then((r) => {
        const firstArch = r.data.metadata.environment.architectures?.[0]
        setServerArch(LXD_TO_UBUNTU_ARCH[firstArch ?? ''] ?? 'amd64')
      })
      .catch(() => { /* keep default amd64 */ })
  }, [])

  useEffect(() => {
    setLoadingNetworks(true)
    setNetworkLoadError(null)

    listNetworks()
      .then((r) => {
        const items = r.data.metadata ?? []
        setAvailableNetworks(items)

        const defaultInterfaces = buildDefaultNetworkInterfaces(items)
        syncInterfacesToConfig(defaultInterfaces)
        setSelectedNetwork(defaultInterfaces[0]?.network ?? items[0]?.name ?? '')
        setNetworkInterfacesError(null)
      })
      .catch((e) => {
        setNetworkLoadError(String(e))
      })
      .finally(() => {
        setLoadingNetworks(false)
      })
  }, [])

  useEffect(() => {
    if (initialAlias?.trim()) {
      setAlias(initialAlias.trim())
      setAutoinstall(isAutoInstallAllowed(initialAlias.trim()))
      if (!nameEdited) {
        setName(suggestVmNameFromAlias(initialAlias))
      }
      setActiveTab('general')
    }
  }, [initialAlias, nameEdited])

  useEffect(() => {
    const el = document.getElementById('createInstanceModal')
    if (!el) return

    const handleShown = () => {
      closeNotifiedRef.current = false
    }

    const handleHidden = () => {
      resetForm()
      cleanupModalArtifacts()
      handleClose()
    }

    el.addEventListener('shown.bs.modal', handleShown)
    el.addEventListener('hidden.bs.modal', handleHidden)
    return () => {
      el.removeEventListener('shown.bs.modal', handleShown)
      el.removeEventListener('hidden.bs.modal', handleHidden)
    }
  }, [onClose])

  useEffect(() => {
    if (!activeOperationId) return

    let cancelled = false

    const pollOperation = async () => {
      try {
        const response = await getOperation(activeOperationId)
        if (cancelled) return

        const operation = response.data.metadata
        const nextDescription = operation.description || null
        setOperationDescription(nextDescription)
        setOperationStatus(operation.status || null)

        if (nextDescription) {
          setOperationLog((prev) => {
            if (prev.length > 0 && prev[prev.length - 1].description === nextDescription) {
              return prev
            }

            const next = [
              ...prev,
              {
                at: new Date().toLocaleTimeString(),
                description: nextDescription,
              },
            ]

            return next.slice(-8)
          })
        }

        if (operation.status === 'Success') {
          setBusy(false)
          setActiveOperationId(null)
          const modalEl = document.getElementById('createInstanceModal')
          if (modalEl) {
            const modal = Modal.getInstance(modalEl) ?? Modal.getOrCreateInstance(modalEl)
            modal.hide()
            window.setTimeout(cleanupModalArtifacts, 0)
          }
          onCreated()
          return
        }

        if (operation.status === 'Failure') {
          setBusy(false)
          setActiveOperationId(null)
          setError(operation.error || 'Build failed')
          return
        }

        window.setTimeout(pollOperation, 1000)
      } catch (e) {
        if (cancelled) return
        setBusy(false)
        setActiveOperationId(null)
        setError(String(e))
      }
    }

    pollOperation()

    return () => {
      cancelled = true
    }
  }, [activeOperationId, onCreated])

  const handleSubmit = async () => {
    if (!name.trim()) return

    if (hasDuplicateDevice(networkInterfaces)) {
      setNetworkInterfacesError('Device names must be unique')
      return
    }

    if (hasInvalidDeviceName(networkInterfaces)) {
      setNetworkInterfacesError('Device names must start with a letter and contain only letters, digits, _, . or -')
      return
    }

    const normalizedForwardedPorts = splitForwardedPorts(forwardedPorts)
    const invalidForwardedPorts = findInvalidForwardedPorts(normalizedForwardedPorts)
    if (invalidForwardedPorts.length > 0) {
      setForwardedPortsError('Forwarded ports must match host:guest/(tcp|udp|both) with ports between 1 and 65535')
      return
    }

    setBusy(true)
    setError(null)
    try {
      const cpuValue = Math.max(1, Number.parseInt(cpu, 10) || 1)
      const memoryValue = Math.max(256, Number.parseInt(memoryMB, 10) || 512)
      const diskValue = Math.max(1, Number.parseInt(diskGB, 10) || 10)
      const normalizedOtherGroups = otherGroups
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean)
      const devices = networkInterfaces.reduce<Record<string, Record<string, string>>>((acc, iface) => {
        acc[iface.device] = {
          type: 'nic',
          name: iface.device,
          network: iface.network,
        }
        return acc
      }, {})

      const config: Record<string, string> = {
        'limits.cpu': String(cpuValue),
        'limits.memory': `${memoryValue}MB`,
        'limits.disk': `${diskValue}GB`,
        'boot.autostart': String(autostart),
      }

      if (networks.trim()) {
        config['cloud-init.network-config'] = networks.trim()
      }

      if (sshAuthorizedKey.trim()) {
        const keyName = user.trim() || 'default'
        config[`cloud-init.ssh-keys.${keyName}`] = sshAuthorizedKey.trim()
      }

      const response = await createInstance({
        name: name.trim(),
        type: type,
        description: description,
        source: { type: 'image', alias },
        config: config,
        ...(Object.keys(devices).length > 0 ? { devices } : {user: "admin"}),
        ...(user.trim() ? { user: user.trim() } : {}),
        ...(password.trim() ? { password: password.trim() } : { password: "admin" }),
        clearPassword: clearPassword,
        ...(mainGroup.trim() ? { mainGroup: mainGroup.trim() } : { mainGroup: "admin" }),
        ...(normalizedOtherGroups.length > 0 ? { other_groups: normalizedOtherGroups } : { other_groups: ["sudo"] }),
        ...(normalizedForwardedPorts.length > 0 ? { forwarded_ports: normalizedForwardedPorts } : {}),
        net_ifnames: netIfnames,
        autostart: autostart,
        autoinstall: autoinstall && isAutoInstallAllowed(alias),
        bridged_network: bridgedNetwork,
        nested: nested,
        dynamic_port_forwarding: dynamicPortForwarding,
        enable_console: enableConsole,
      })

      const operation = response.data.metadata
      const operationId = operation.id || response.data.operation.split('/').filter(Boolean).pop() || null

      if (!operationId) {
        throw new Error('Unable to track build operation')
      }

      const initialDescription = operation.description || 'Starting build…'
      setOperationDescription(initialDescription)
      setOperationStatus(operation.status || 'Running')
      setOperationLog([
        {
          at: new Date().toLocaleTimeString(),
          description: initialDescription,
        },
      ])
      setActiveOperationId(operationId)
    } catch (e) {
      setBusy(false)
      setError(String(e))
    }
  }

  const assignRandomName = () => {
    setName(generateRandomVmName())
    setNameEdited(true)
  }

  const operationProgress = parseProgressPercent(operationDescription)

  return (
    <div
      className="modal fade"
      id="createInstanceModal"
      tabIndex={-1}
      aria-hidden="true"
    >
      <div className="modal-dialog modal-lg">
        <div className="modal-content">
          <div className="modal-header">
            <div>
              <h5 className="modal-title mb-1">New Instance</h5>
              {hasSourceContext && (
                <div className="small text-muted d-flex align-items-center gap-2">
                  <span className="badge bg-info-subtle text-info-emphasis border">Source: remote image</span>
                  <span>{sourceAlias}</span>
                </div>
              )}
            </div>
            <button
              type="button"
              className="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
              disabled={busy}
              onClick={handleClose}
            />
          </div>
          <div className="modal-body">
            {error && <div className="alert alert-danger">{error}</div>}
            {busy && activeOperationId && (
              <div className="alert alert-info d-flex align-items-start gap-2">
                <Spinner size="sm" />
                <div>
                  <div className="fw-medium">Build in progress</div>
                  <div className="small">{operationDescription || 'Waiting for status update…'}</div>
                  {operationStatus && (
                    <div className="small text-muted">Status: {operationStatus}</div>
                  )}
                  {operationProgress !== null && (
                    <>
                      <div className="progress mt-2" role="progressbar" aria-label="Build progress" aria-valuenow={operationProgress} aria-valuemin={0} aria-valuemax={100}>
                        <div
                          className="progress-bar progress-bar-striped progress-bar-animated"
                          style={{ width: `${operationProgress}%` }}
                        >
                          {operationProgress}%
                        </div>
                      </div>
                      <div className="small text-muted mt-1">Estimated progress extracted from operation message</div>
                    </>
                  )}
                  {operationLog.length > 1 && (
                    <details className="mt-2">
                      <summary className="small fw-medium" style={{ cursor: 'pointer' }}>
                        Operation updates ({operationLog.length})
                      </summary>
                      <ul className="small mb-0 ps-3 mt-1">
                        {operationLog.map((entry, index) => (
                          <li key={`${entry.at}-${index}`}>
                            <span className="text-muted me-1">[{entry.at}]</span>
                            <span>{entry.description}</span>
                          </li>
                        ))}
                      </ul>
                    </details>
                  )}
                </div>
              </div>
            )}
            <ul className="nav nav-tabs mb-3" role="tablist">
              <li className="nav-item" role="presentation">
                <button
                  type="button"
                  className={`nav-link ${activeTab === 'general' ? 'active' : ''}`}
                  onClick={() => setActiveTab('general')}
                >
                  General
                </button>
              </li>
              <li className="nav-item" role="presentation">
                <button
                  type="button"
                  className={`nav-link ${activeTab === 'system' ? 'active' : ''}`}
                  onClick={() => setActiveTab('system')}
                >
                  System
                </button>
              </li>
              <li className="nav-item" role="presentation">
                <button
                  type="button"
                  className={`nav-link ${activeTab === 'access' ? 'active' : ''}`}
                  onClick={() => setActiveTab('access')}
                >
                  Access
                </button>
              </li>
              <li className="nav-item" role="presentation">
                <button
                  type="button"
                  className={`nav-link ${activeTab === 'network' ? 'active' : ''}`}
                  onClick={() => setActiveTab('network')}
                >
                  Network
                </button>
              </li>
            </ul>

            <div className="tab-content">
              <div className={`tab-pane fade ${activeTab === 'general' ? 'show active' : ''}`}>
                <div className="mb-3">
                  <label className="form-label fw-medium">Name</label>
                  <div className="input-group">
                    <input
                      className="form-control"
                      value={name}
                      onChange={(e) => {
                        setName(e.target.value)
                        setNameEdited(true)
                      }}
                      placeholder="my-vm"
                    />
                    <button
                      type="button"
                      className="btn btn-outline-secondary"
                      onClick={assignRandomName}
                    >
                      Random
                    </button>
                  </div>
                </div>
                <div className="mb-3">
                  <label className="form-label fw-medium">Type</label>
                  <select
                    className="form-select"
                    value={type}
                    onChange={(e) =>
                      setType(e.target.value as 'virtual-machine' | 'container')
                    }
                  >
                    <option value="virtual-machine">Virtual Machine</option>
                    <option value="container">Container</option>
                  </select>
                </div>
                <div className="mb-3">
                  <label className="form-label fw-medium">Image alias or ISO</label>
                  {(() => {
                    const macosIpswSources = buildMacosIpswSources(serverArch)
                    const cloudSources = buildSourceImages(serverArch, false)
                    const isoSources = buildSourceImages(serverArch, true)

                    return (
                  <select
                    className="form-select"
                    value={alias}
                    onChange={(e) => {
                      setAlias(e.target.value)
                      setAutoinstall(isAutoInstallAllowed(e.target.value))
                    }}
                  >
                    <option value="">Select or type image alias...</option>
                    {macosIpswSources.length > 0 && (
                      <optgroup label="macOS IPSW">
                        {macosIpswSources.map((opt) => (
                          <option key={opt.url} value={opt.url}>
                            {opt.label}
                          </option>
                        ))}
                      </optgroup>
                    )}
                    <optgroup label="Cloud Images">
                      {cloudSources.map((opt) => (
                        <option key={opt.url} value={opt.url}>
                          {opt.label}
                        </option>
                      ))}
                    </optgroup>
                    <optgroup label="ISOs">
                      {isoSources.map((opt) => (
                        <option key={opt.url} value={opt.url}>
                          {opt.label}
                        </option>
                      ))}
                    </optgroup>
                  </select>
                    )
                  })()}
                  <input
                    type="text"
                    className="form-control mt-2"
                    value={alias}
                    onChange={(e) => {
                      setAlias(e.target.value)
                      setAutoinstall(isAutoInstallAllowed(e.target.value))
                    }}
                    placeholder="ubuntu:22.04"
                  />
                </div>
                <div className="mb-0">
                  <label className="form-label fw-medium">Description</label>
                  <input
                    className="form-control"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Optional"
                  />
                </div>
              </div>

              <div className={`tab-pane fade ${activeTab === 'system' ? 'show active' : ''}`}>
                <div className="row g-3">
                  <div className="col-md-4">
                    <label className="form-label fw-medium">CPU</label>
                    <input
                      type="number"
                      min={1}
                      className="form-control"
                      value={cpu}
                      onChange={(e) => setCpu(e.target.value)}
                      placeholder="2"
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-medium">Memory (MB)</label>
                    <input
                      type="number"
                      min={256}
                      step={256}
                      className="form-control"
                      value={memoryMB}
                      onChange={(e) => setMemoryMB(e.target.value)}
                      placeholder="2048"
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-medium">Disk size (GB)</label>
                    <input
                      type="number"
                      min={1}
                      className="form-control"
                      value={diskGB}
                      onChange={(e) => setDiskGB(e.target.value)}
                      placeholder="20"
                    />
                  </div>
                </div>
                <div className="mt-3">
                  <div className="form-check form-switch mb-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-autostart"
                      checked={autostart}
                      onChange={(e) => setAutostart(e.target.checked)}
                    />
                    <label className="form-check-label" htmlFor="create-autostart">Autostart</label>
                  </div>
                  <div className="form-check form-switch mb-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-nested"
                      checked={nested}
                      onChange={(e) => setNested(e.target.checked)}
                    />
                    <label className="form-check-label" htmlFor="create-nested">Nested virtualization</label>
                  </div>
                  <div className="form-check form-switch mb-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-net-ifnames"
                      checked={netIfnames}
                      onChange={(e) => {
                        const checked = e.target.checked
                        setNetIfnames(checked)
                        const renamed = networkInterfaces.map((item, index) => ({
                          ...item,
                          device: defaultDeviceName(index, checked),
                        }))
                        syncInterfacesToConfig(renamed)
                        setNetworkInterfacesError(null)
                      }}
                    />
                    <label className="form-check-label" htmlFor="create-net-ifnames">Use net.ifnames</label>
                  </div>
                  <div className="form-check form-switch mb-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-bridged-network"
                      checked={bridgedNetwork}
                      onChange={(e) => setBridgedNetwork(e.target.checked)}
                    />
                    <label className="form-check-label" htmlFor="create-bridged-network">Bridged network</label>
                  </div>
                  <div className="form-check form-switch">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-dynamic-port-forwarding"
                      checked={dynamicPortForwarding}
                      onChange={(e) => setDynamicPortForwarding(e.target.checked)}
                    />
                    <label className="form-check-label" htmlFor="create-dynamic-port-forwarding">Dynamic port forwarding</label>
                  </div>
                  <div className="form-check form-switch mt-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-enable-console"
                      checked={enableConsole}
                      onChange={(e) => setEnableConsole(e.target.checked)}
                    />
                    <label className="form-check-label" htmlFor="create-enable-console">Enable log console</label>
                  </div>
                  <div className="form-check form-switch mt-2">
                    <input
                      className="form-check-input"
                      type="checkbox"
                      id="create-autoinstall"
                      checked={autoinstall}
                      disabled={!isAutoInstallAllowed(alias)}
                      onChange={(e) => setAutoinstall(e.target.checked)}
                    />
                    <label className={`form-check-label${!isAutoInstallAllowed(alias) ? ' text-muted' : ''}`} htmlFor="create-autoinstall">
                      Autoinstall
                      {!isAutoInstallAllowed(alias) && <span className="ms-1 small">(Ubuntu only)</span>}
                    </label>
                  </div>
                </div>
              </div>

              <div className={`tab-pane fade ${activeTab === 'access' ? 'show active' : ''}`}>
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">User</label>
                    <input
                      className="form-control"
                      value={user}
                      onChange={(e) => setUser(e.target.value)}
                      placeholder="admin"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Password</label>
                    <input
                      type="password"
                      className="form-control"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="admin (if empty)"
                    />
                    <div className="form-check mt-2">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="create-clear-password"
                        checked={clearPassword}
                        onChange={(e) => setClearPassword(e.target.checked)}
                      />
                      <label className="form-check-label text-nowrap" htmlFor="create-clear-password">Allow SSH password authentication</label>
                    </div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Main group</label>
                    <input
                      className="form-control"
                      value={mainGroup}
                      onChange={(e) => setMainGroup(e.target.value)}
                      placeholder="adm"
                    />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium text-nowrap">Other groups (comma-separated)</label>
                    <input
                      className="form-control"
                      value={otherGroups}
                      onChange={(e) => setOtherGroups(e.target.value)}
                      placeholder="sudo,docker"
                    />
                  </div>
                  <div className="col-12">
                    <label className="form-label fw-medium">SSH authorized key</label>
                    <textarea
                      className="form-control"
                      rows={3}
                      value={sshAuthorizedKey}
                      onChange={(e) => setSshAuthorizedKey(e.target.value)}
                      placeholder="ssh-ed25519 AAAA... user@host"
                    />
                  </div>
                  <div className="col-12">
                    <label className="form-label fw-medium">Forwarded ports (comma or newline separated)</label>
                    <textarea
                      className="form-control"
                      rows={2}
                      value={forwardedPorts}
                      onChange={(e) => updateForwardedPorts(e.target.value)}
                      placeholder="2022:22/tcp,8080:80/tcp"
                    />
                    {forwardedPortsError && <div className="text-danger small mt-1">{forwardedPortsError}</div>}
                  </div>
                </div>
              </div>

              <div className={`tab-pane fade ${activeTab === 'network' ? 'show active' : ''}`}>
                <label className="form-label fw-medium">Network interfaces</label>
                <div className="input-group mb-2">
                  <select
                    className="form-select"
                    value={selectedNetwork}
                    onChange={(e) => setSelectedNetwork(e.target.value)}
                    disabled={loadingNetworks || availableNetworks.length === 0}
                  >
                    {availableNetworks.length === 0 && (
                      <option value="">{loadingNetworks ? 'Loading networks…' : 'No networks available'}</option>
                    )}
                    {availableNetworks.map((net) => (
                      <option key={net.name} value={net.name}>{net.name}</option>
                    ))}
                  </select>
                  <button
                    type="button"
                    className="btn btn-outline-primary"
                    onClick={addNetworkInterface}
                    disabled={
                      !selectedNetwork
                      || loadingNetworks
                      || availableNetworks.length === 0
                      || networkInterfaces.some((item) => item.network === selectedNetwork)
                    }
                  >
                    Add interface
                  </button>
                </div>
                {networkLoadError && <div className="text-danger small mb-2">{networkLoadError}</div>}
                {networkInterfacesError && <div className="text-danger small mb-2">{networkInterfacesError}</div>}

                {networkInterfaces.length > 0 && (
                  <div className="border rounded p-2 mb-2">
                    {networkInterfaces.map((iface, index) => (
                      <div key={`${iface.network}-${index}`} className="row g-2 align-items-center mb-2">
                        <div className="col-5">
                          <input className="form-control" value={iface.network} readOnly />
                        </div>
                        <div className="col-5">
                          <input
                            className="form-control"
                            value={iface.device}
                            onChange={(e) => updateInterfaceDevice(index, e.target.value)}
                            placeholder={defaultDeviceName(index)}
                          />
                        </div>
                        <div className="col-2 text-end">
                          <button
                            type="button"
                            className="btn btn-outline-danger btn-sm"
                            onClick={() => removeNetworkInterface(index)}
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                <label className="form-label fw-medium">Networks config</label>
                <textarea
                  className="form-control"
                  rows={4}
                  value={networks}
                  onChange={(e) => setNetworks(e.target.value)}
                  placeholder="#cloud-config\nnetwork:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true"
                />
                <div className="form-text">
                  Add interfaces from /1.0/networks or edit YAML manually. Sent as <code>network_config</code>.
                </div>
              </div>
            </div>
          </div>
          <div className="modal-footer">
            <button
              type="button"
              className="btn btn-secondary"
              data-bs-dismiss="modal"
              disabled={busy}
              onClick={handleClose}
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy || !name.trim() || Boolean(forwardedPortsError)}
              onClick={handleSubmit}
            >
              {busy ? <><Spinner size="sm" /> <span className="ms-1">Building...</span></> : 'Create'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
