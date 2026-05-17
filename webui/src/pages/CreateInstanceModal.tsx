import { useEffect, useState } from 'react';
import { createInstance } from '../api/instances';
import { listNetworks } from '../api/networks';
import { Spinner } from '../components/Spinner';
import type { LXDNetwork } from '../types/lxd';

interface Props {
  onCreated: () => void
  initialAlias?: string
}

interface NetworkInterfaceItem {
  network: string
  device: string
}

const DEVICE_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_.-]*$/
const FORWARDED_PORT_PATTERN = /^(\d{1,5}):(\d{1,5})\/(tcp|udp|both)$/i
const VM_NAME_ADJECTIVES = ['swift', 'brave', 'calm', 'silent', 'lucky', 'rapid', 'crisp', 'frosty']
const VM_NAME_NOUNS = ['otter', 'falcon', 'cedar', 'pine', 'ember', 'comet', 'delta', 'harbor']
const DEFAULT_IMAGE_ALIAS = 'ubuntu/26.04'

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
  const suffix = Math.floor(100 + Math.random() * 900)
  return `${base}-${suffix}`
}

export function CreateInstanceModal({ onCreated, initialAlias }: Props) {
  const sourceAlias = initialAlias?.trim() || ''
  const hasSourceContext = sourceAlias.length > 0

  const [activeTab, setActiveTab] = useState<'general' | 'system' | 'access' | 'network'>('general')
  const [name, setName] = useState(generateRandomVmName())
  const [nameEdited, setNameEdited] = useState(false)
  const [alias, setAlias] = useState(initialAlias?.trim() || DEFAULT_IMAGE_ALIAS)
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
  const [networks, setNetworks] = useState('')
  const [availableNetworks, setAvailableNetworks] = useState<LXDNetwork[]>([])
  const [networkInterfaces, setNetworkInterfaces] = useState<NetworkInterfaceItem[]>([])
  const [selectedNetwork, setSelectedNetwork] = useState('')
  const [loadingNetworks, setLoadingNetworks] = useState(false)
  const [networkLoadError, setNetworkLoadError] = useState<string | null>(null)
  const [networkInterfacesError, setNetworkInterfacesError] = useState<string | null>(null)
  const [forwardedPortsError, setForwardedPortsError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

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

  const buildNetworkConfig = (items: NetworkInterfaceItem[]) => {
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

  const syncInterfacesToConfig = (items: NetworkInterfaceItem[]) => {
    setNetworkInterfaces(items)
    setNetworks(buildNetworkConfig(items))
  }

  const addNetworkInterface = () => {
    if (!selectedNetwork) return

    if (networkInterfaces.some((item) => item.network === selectedNetwork)) {
      setNetworkInterfacesError(`Network \"${selectedNetwork}\" is already added`)
      return
    }

    const next: NetworkInterfaceItem[] = [
      ...networkInterfaces,
      { network: selectedNetwork, device: `eth${networkInterfaces.length}` },
    ]
    setNetworkInterfacesError(null)
    syncInterfacesToConfig(next)
  }

  const removeNetworkInterface = (index: number) => {
    const next = networkInterfaces
      .filter((_, i) => i !== index)
      .map((item, i) => ({ ...item, device: `eth${i}` }))

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
    const next = networkInterfaces.map((item, i) => (i === index ? { ...item, device: value || `eth${index}` } : item))

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
    setLoadingNetworks(true)
    setNetworkLoadError(null)

    listNetworks()
      .then((r) => {
        const items = r.data.metadata ?? []
        setAvailableNetworks(items)
        if (items.length > 0) setSelectedNetwork(items[0].name)
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
      if (!nameEdited) {
        setName(suggestVmNameFromAlias(initialAlias))
      }
      setActiveTab('general')
    }
  }, [initialAlias, nameEdited])

  useEffect(() => {
    const el = document.getElementById('createInstanceModal')
    if (!el) return

    const handleHidden = () => {
      setNameEdited(false)
    }

    el.addEventListener('hidden.bs.modal', handleHidden)
    return () => {
      el.removeEventListener('hidden.bs.modal', handleHidden)
    }
  }, [])

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

      await createInstance({
        name: name.trim(),
        type,
        description,
        source: { type: 'image', alias },
        config,
        ...(Object.keys(devices).length > 0 ? { devices } : {}),
        ...(user.trim() ? { user: user.trim() } : {}),
        ...(password.trim() ? { password: password.trim() } : {}),
        clearPassword,
        ...(mainGroup.trim() ? { mainGroup: mainGroup.trim() } : {}),
        ...(normalizedOtherGroups.length > 0 ? { other_groups: normalizedOtherGroups } : {}),
        ...(normalizedForwardedPorts.length > 0 ? { forwarded_ports: normalizedForwardedPorts } : {}),
        net_ifnames: netIfnames,
        bridged_network: bridgedNetwork,
        nested,
        dynamic_port_forwarding: dynamicPortForwarding,
      })
      // Reset form
      setName(generateRandomVmName())
      setNameEdited(false)
      setAlias(initialAlias?.trim() || DEFAULT_IMAGE_ALIAS)
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
      setActiveTab('general')
      setNetworks('')
      setNetworkInterfaces([])
      setNetworkInterfacesError(null)
      // Close modal
      const el = document.getElementById('createInstanceModal')
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const m = (window as any).bootstrap?.Modal?.getInstance(el)
      m?.hide()
      onCreated()
    } catch (e) {
      setError(String(e))
    } finally {
      setBusy(false)
    }
  }

  const assignRandomName = () => {
    setName(generateRandomVmName())
    setNameEdited(true)
  }

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
            />
          </div>
          <div className="modal-body">
            {error && <div className="alert alert-danger">{error}</div>}
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
                  <label className="form-label fw-medium">Image alias</label>
                  <input
                    className="form-control"
                    value={alias}
                    onChange={(e) => setAlias(e.target.value)}
                    placeholder="ubuntu/22.04"
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
                      onChange={(e) => setNetIfnames(e.target.checked)}
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
                      placeholder="Optional"
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
                            placeholder={`eth${index}`}
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
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy || !name.trim() || Boolean(forwardedPortsError)}
              onClick={handleSubmit}
            >
              {busy ? <Spinner size="sm" /> : 'Create'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
