import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { changeInstanceState, consoleInstance, deleteInstance, execInstance, getInstance, getInstanceLogFile, getInstanceLogs, getInstanceState, patchInstance } from '../api/instances';
import { listNetworks } from '../api/networks';
import { PageSpinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import { TerminalConsole } from '../components/TerminalConsole';
import { VGAConsole, VGAConsoleHandle } from '../components/VGAConsole';
import type { LXDInstance, LXDInstanceState, LXDNetwork, LXDPatchInstanceRequest } from '../types/lxd';
import { eventBus } from '../utils/eventBus';

type ActiveTab = 'overview' | 'terminal' | 'vga' | 'logs' | 'settings'

interface ConsoleSession {
  operationId: string
  fds: Record<string, string>
}

interface NetworkDeviceEditor {
  device: string
  network: string
}

interface SettingsFormState {
  cpu: string
  memoryMB: string
  diskGB: string
  autostart: boolean
  nested: boolean
  suspendable: boolean
  dynamicPortForwarding: boolean
  networks: NetworkDeviceEditor[]
}

// ─── Overview panel ──────────────────────────────────────────────────────────

function OverviewPanel({ instance, state }: { instance: LXDInstance; state: LXDInstanceState | null }) {
  const formatBytes = (b: number) => {
    if (b >= 1073741824) return `${(b / 1073741824).toFixed(1)} GB`
    if (b >= 1048576) return `${(b / 1048576).toFixed(1)} MB`
    return `${b} B`
  }

  const pct = (used: number, total: number) =>
    total > 0 ? Math.round((used / total) * 100) : 0

  const knownConfigLabels: Record<string, string> = {
    'limits.cpu': 'CPU limit',
    'limits.memory': 'Memory limit',
    'limits.disk': 'Disk limit',
    'boot.autostart': 'Autostart',
    'security.nesting': 'Nested virtualization',
    'user.caker.suspendable': 'Suspendable mode',
    'user.caker.dynamic_port_forwarding': 'Dynamic port forwarding',
    'user.caker.enable_console': 'Console enabled',
  }

  const humanizeConfigKey = (key: string) => {
    const mapped = knownConfigLabels[key]
    if (mapped) return mapped

    return key
      .split(/[._-]+/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ')
  }

  const sortedConfigEntries = Object.entries(instance.config ?? {}).sort(([a], [b]) =>
    a.localeCompare(b),
  )

  return (
    <div className="row g-4 p-4">
      {/* Identity */}
      <div className="col-12 col-lg-6">
        <div className="card border-0 shadow-sm h-100">
          <div className="card-header bg-transparent fw-semibold">
            <i className="bi bi-info-circle me-2 text-primary" />
            Identity
          </div>
          <div className="card-body">
            <dl className="row mb-0 small">
              <dt className="col-5 text-muted">Name</dt>
              <dd className="col-7">{instance.name}</dd>
              <dt className="col-5 text-muted">Type</dt>
              <dd className="col-7">{instance.type}</dd>
              <dt className="col-5 text-muted">Status</dt>
              <dd className="col-7">
                <StatusBadge status={instance.status} />
              </dd>
              <dt className="col-5 text-muted">Architecture</dt>
              <dd className="col-7">{instance.architecture || '—'}</dd>
              <dt className="col-5 text-muted">Description</dt>
              <dd className="col-7">{instance.description || '—'}</dd>
              <dt className="col-5 text-muted">Profiles</dt>
              <dd className="col-7">{instance.profiles.join(', ') || '—'}</dd>
              <dt className="col-5 text-muted">Created</dt>
              <dd className="col-7">{instance.created_at ? new Date(instance.created_at).toLocaleString() : '—'}</dd>
              <dt className="col-5 text-muted">Last used</dt>
              <dd className="col-7">{instance.last_used_at ? new Date(instance.last_used_at).toLocaleString() : '—'}</dd>
            </dl>
          </div>
        </div>
      </div>

      {/* Resources */}
      {state && (
        <div className="col-12 col-lg-6">
          <div className="card border-0 shadow-sm h-100">
            <div className="card-header bg-transparent fw-semibold">
              <i className="bi bi-cpu me-2 text-primary" />
              Resources
            </div>
            <div className="card-body">
              <p className="small text-muted mb-1">CPU usage</p>
              <div className="progress mb-3" style={{ height: 8 }}>
                <div
                  className="progress-bar"
                  style={{ width: `${Math.min(pct(state.cpu.usage, 1e9), 100)}%` }}
                />
              </div>

              <p className="small text-muted mb-1">
                Memory — {formatBytes(state.memory.usage)} / {formatBytes(state.memory.total)}
              </p>
              <div className="progress mb-3" style={{ height: 8 }}>
                <div
                  className="progress-bar bg-success"
                  style={{ width: `${pct(state.memory.usage, state.memory.total)}%` }}
                />
              </div>

              <dl className="row mb-0 small">
                <dt className="col-5 text-muted">PID</dt>
                <dd className="col-7">{state.pid}</dd>
                <dt className="col-5 text-muted">Processes</dt>
                <dd className="col-7">{state.processes}</dd>
              </dl>
            </div>
          </div>
        </div>
      )}

      {/* Network */}
      {state?.network && Object.keys(state.network).length > 0 && (
        <div className="col-12">
          <div className="card border-0 shadow-sm">
            <div className="card-header bg-transparent fw-semibold">
              <i className="bi bi-diagram-3 me-2 text-primary" />
              Network
            </div>
            <div className="card-body p-0">
              <table className="table table-sm mb-0">
                <thead className="table-light">
                  <tr>
                    <th>Interface</th>
                    <th>State</th>
                    <th>MAC</th>
                    <th>Addresses</th>
                  </tr>
                </thead>
                <tbody>
                  {Object.entries(state.network!).map(([iface, info]) => (
                    <tr key={iface}>
                      <td className="fw-medium">{iface}</td>
                      <td>
                        <span className={`badge ${info.state === 'up' ? 'bg-success' : 'bg-secondary'}`}>
                          {info.state}
                        </span>
                      </td>
                      <td><code className="small">{info.hwaddr}</code></td>
                      <td>
                        {info.addresses
                          .filter((a) => a.scope !== 'link')
                          .map((a) => (
                            <div key={a.address}>
                              <code className="small">{a.address}/{a.netmask}</code>
                              <span className="text-muted ms-1 small">({a.family})</span>
                            </div>
                          ))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* Config */}
      {sortedConfigEntries.length > 0 && (
        <div className="col-12">
          <div className="card border-0 shadow-sm">
            <div className="card-header bg-transparent fw-semibold">
              <i className="bi bi-gear me-2 text-primary" />
              Configuration
            </div>
            <div className="card-body p-0">
              <table className="table table-sm mb-0">
                <thead className="table-light">
                  <tr>
                    <th>Key</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedConfigEntries.map(([k, v]) => (
                    <tr key={k}>
                      <td>
                        <div className="fw-medium">{humanizeConfigKey(k)}</div>
                        <code className="small text-muted">{k}</code>
                      </td>
                      <td><code className="small">{v}</code></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Console tab placeholder ──────────────────────────────────────────────────

function NotRunningPlaceholder({ label }: { label: string }) {
  return (
    <div className="d-flex flex-column align-items-center justify-content-center h-100 text-muted gap-3">
      <i className="bi bi-power fs-1" />
      <p className="mb-0">Start the instance to open the {label}.</p>
    </div>
  )
}

function ConsoleLoading() {
  return (
    <div className="d-flex flex-column align-items-center justify-content-center h-100 gap-3">
      <div className="spinner-border text-primary" />
      <span className="text-muted">Opening session…</span>
    </div>
  )
}

function parsePositiveInt(value: string): number | null {
  const parsed = Number.parseInt(value, 10)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null
}

function parseLimitValue(raw: string | undefined, defaultValue: number): string {
  if (!raw) return String(defaultValue)
  const parsed = Number.parseInt(raw, 10)
  return Number.isFinite(parsed) && parsed > 0 ? String(parsed) : String(defaultValue)
}

function parseBooleanConfig(raw: string | undefined, defaultValue = false): boolean {
  if (!raw) return defaultValue
  const normalized = raw.trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false
  return defaultValue
}

function buildDefaultDeviceName(index: number): string {
  return `eth${index}`
}

function shouldRetryVGAReconnect(status: string | undefined): boolean {
  return status === 'Running' || status === 'Starting' || status === 'Stopping' || status === 'Pending'
}

function extractNetworksFromDevices(devices: Record<string, Record<string, string>>): NetworkDeviceEditor[] {
  const entries = Object.entries(devices)
    .filter(([, spec]) => (spec.type || '').toLowerCase() === 'nic' && !!spec.network)
    .map(([deviceName, spec], index) => ({
      device: spec.name || deviceName || buildDefaultDeviceName(index),
      network: spec.network,
    }))

  return entries.sort((a, b) => a.device.localeCompare(b.device))
}

// ─── Logs panel ───────────────────────────────────────────────────────────────

interface LogsPanelProps {
  logs: string[]
  selectedLog: string | null
  onLogSelect: (log: string) => void
  logContent: string | null
  loading: boolean
  error: string | null
}

function LogsPanel({ logs, selectedLog, onLogSelect, logContent, loading, error }: LogsPanelProps) {
  const getLogDisplayName = (logPath: string) => logPath.split('/').pop() || logPath

  return (
    <div style={{ display: 'flex', height: '100%', gap: 0 }}>
      {/* Logs list */}
      <div style={{ width: '18%', borderRight: '1px solid #dee2e6', overflowY: 'auto', padding: '12px' }}>
        {logs.length === 0 ? (
          <p className="text-muted small mb-0">No logs available</p>
        ) : (
          <div className="list-group list-group-sm">
            {logs.map((log) => (
              <button
                key={log}
                onClick={() => onLogSelect(log)}
                className={`list-group-item list-group-item-action ${selectedLog === log ? 'active' : ''}`}
                style={{ fontSize: '0.875rem' }}
                title={log}
              >
                <i className="bi bi-file-text me-2" />
                {getLogDisplayName(log)}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Log content */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        {!selectedLog ? (
          <div className="d-flex flex-column align-items-center justify-content-center h-100 text-muted">
            <i className="bi bi-file-text fs-1 mb-2" />
            <p className="mb-0">Select a log file to view</p>
          </div>
        ) : loading ? (
          <div className="d-flex flex-column align-items-center justify-content-center h-100 gap-3">
            <div className="spinner-border text-primary" />
            <span className="text-muted">Loading log…</span>
          </div>
        ) : error ? (
          <div className="p-3">
            <div className="alert alert-danger d-flex align-items-center gap-2 mb-0">
              <i className="bi bi-exclamation-triangle-fill" />
              {error}
            </div>
          </div>
        ) : logContent ? (
          <div style={{ flex: 1, overflow: 'auto', padding: '12px' }}>
            <pre
              style={{
                margin: 0,
                fontSize: '0.75rem',
                backgroundColor: '#f8f9fa',
                padding: '12px',
                borderRadius: '4px',
                whiteSpace: 'pre-wrap',
                wordWrap: 'break-word',
              }}
            >
              {logContent}
            </pre>
          </div>
        ) : null}
      </div>
    </div>
  )
}

// ─── Main page ────────────────────────────────────────────────────────────────

export function InstanceDetailPage() {
  const { name } = useParams<{ name: string }>()
  const navigate = useNavigate()
  const [instance, setInstance] = useState<LXDInstance | null>(null)
  const [state, setState] = useState<LXDInstanceState | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)

  const [activeTab, setActiveTab] = useState<ActiveTab>('overview')

  // Sessions – established lazily when the tab is first activated.
  // Kept in refs so they survive re-renders without triggering effects.
  const [termSession, setTermSession] = useState<ConsoleSession | null>(null)
  const [vgaSession, setVgaSession] = useState<ConsoleSession | null>(null)
  const [sessionError, setSessionError] = useState<string | null>(null)
  const [sessionLoading, setSessionLoading] = useState(false)

  // Logs state
  const [logs, setLogs] = useState<string[]>([])
  const [selectedLog, setSelectedLog] = useState<string | null>(null)
  const [logContent, setLogContent] = useState<string | null>(null)
  const [logsLoading, setLogsLoading] = useState(false)
  const [logsError, setLogsError] = useState<string | null>(null)
  const [logContentLoading, setLogContentLoading] = useState(false)
  const [logContentError, setLogContentError] = useState<string | null>(null)

  // Busy state for start/stop
  const [actionBusy, setActionBusy] = useState<string | null>(null)

  // Editable settings state
  const [settingsForm, setSettingsForm] = useState<SettingsFormState>({
    cpu: '2',
    memoryMB: '2048',
    diskGB: '20',
    autostart: false,
    nested: false,
    suspendable: false,
    dynamicPortForwarding: false,
    networks: [],
  })
  const [settingsBusy, setSettingsBusy] = useState(false)
  const [settingsError, setSettingsError] = useState<string | null>(null)
  const [settingsSuccess, setSettingsSuccess] = useState<string | null>(null)
  const [availableNetworks, setAvailableNetworks] = useState<LXDNetwork[]>([])
  const [selectedNetwork, setSelectedNetwork] = useState('')
  const [loadingNetworks, setLoadingNetworks] = useState(false)

  // Track which sessions have been requested to avoid duplicate calls.
  const termRequested = useRef(false)
  const termReconnectRequested = useRef(false)
  const vgaRequested = useRef(false)
  const vgaReconnectRequested = useRef(false)
  const logsRequested = useRef(false)
  const vgaConsoleRef = useRef<VGAConsoleHandle>(null)

  // ── Load instance info ─────────────────────────────────────────────────────
  // Rafraîchissement initial et sur changement de nom
  useEffect(() => {
    if (!name) return
    let cancelled = false
    Promise.all([
      getInstance(name).then((r) => { if (!cancelled) setInstance(r.data.metadata) }),
      getInstanceState(name)
        .then((r) => { if (!cancelled) setState(r.data.metadata) })
        .catch(() => { if (!cancelled) setState(null) }),
    ]).catch((e) => setLoadError(String(e)))
    return () => { cancelled = true }
  }, [name])

  // Rafraîchissement automatique (polling) hors action utilisateur
  useEffect(() => {
    if (!name) return
    let cancelled = false
    let lastStatus: string | undefined = undefined
    const poll = async () => {
      while (!cancelled) {
        try {
          const res = await getInstance(name)
          const status = res.data.metadata.status
          if (lastStatus !== undefined && status !== lastStatus) {
            eventBus.emit('instance-status', { name, status })
          }
          lastStatus = status
          if (!cancelled) {
            setInstance(res.data.metadata)
          }

          try {
            const stateRes = await getInstanceState(name)
            if (!cancelled) {
              setState(stateRes.data.metadata)
            }
          } catch {
            if (!cancelled) {
              setState(null)
            }
          }
        } catch {}
        await new Promise((r) => setTimeout(r, 3000))
      }
    }
    poll()
    return () => { cancelled = true }
  }, [name])

  const isRunning = instance?.status === 'Running'

  // Rafraîchit l'état si eventBus signale un changement (hors action utilisateur)
  useEffect(() => {
    if (!name) return
    const off = eventBus.on('instance-status', (payload) => {
      if (payload.name === name) {
        getInstance(name).then((r) => setInstance(r.data.metadata))
        getInstanceState(name).then((r) => setState(r.data.metadata)).catch(() => {})
      }
    })
    return () => { off() }
  }, [name])

  // Start/Stop actions
  // Poll le statut jusqu'à changement ou timeout (maxWait ms)
  const pollStatusChange = async (expected: string, maxWait = 8000, interval = 700) => {
    const start = Date.now()
    while (Date.now() - start < maxWait) {
      const res = await getInstance(name!)
      const newStatus = res.data.metadata.status
      if (newStatus === expected) {
        setInstance(res.data.metadata)
        try {
          const stateRes = await getInstanceState(name!)
          setState(stateRes.data.metadata)
        } catch {}
        return true
      }
      await new Promise((r) => setTimeout(r, interval))
    }
    return false
  }

  const doStateChange = async (action: 'start' | 'stop') => {
    if (!instance) return
    setActionBusy(action)
    setLoadError(null)
    try {
      await changeInstanceState(instance.name, action)
      // Attendre le changement effectif de statut
      const expected = action === 'start' ? 'Running' : 'Stopped'
      const ok = await pollStatusChange(expected)
      if (!ok) setLoadError("Timeout: l'état n'a pas changé.")
    } catch (e) {
      setLoadError(String(e))
    } finally {
      setActionBusy(null)
    }
  }

  const doDelete = async () => {
    if (!instance || instance.status === 'Running') return
    if (!window.confirm(`Delete instance "${instance.name}"? This action cannot be undone.`)) return

    setActionBusy('delete')
    setLoadError(null)
    try {
      await deleteInstance(instance.name)
      navigate('/instances')
    } catch (e) {
      setLoadError(String(e))
    } finally {
      setActionBusy(null)
    }
  }

  const refreshInstanceData = useCallback(async () => {
    if (!name) return
    const [instanceRes, stateRes] = await Promise.all([
      getInstance(name),
      getInstanceState(name).catch(() => null),
    ])
    setInstance(instanceRes.data.metadata)
    setState(stateRes?.data.metadata ?? null)
  }, [name])

  useEffect(() => {
    if (!instance) return

    const extractedNetworks = extractNetworksFromDevices(instance.expanded_devices ?? {})
    setSettingsForm({
      cpu: parseLimitValue(instance.config?.['limits.cpu'], 2),
      memoryMB: parseLimitValue(instance.config?.['limits.memory'], 2048),
      diskGB: parseLimitValue(instance.config?.['limits.disk'], 20),
      autostart: parseBooleanConfig(instance.config?.['boot.autostart']),
      nested: parseBooleanConfig(instance.config?.['security.nesting']),
      suspendable: parseBooleanConfig(instance.config?.['user.caker.suspendable']),
      dynamicPortForwarding: parseBooleanConfig(instance.config?.['user.caker.dynamic_port_forwarding']),
      networks: extractedNetworks,
    })
  }, [instance])

  const loadAvailableNetworks = useCallback(async () => {
    setLoadingNetworks(true)
    try {
      const res = await listNetworks()
      const items = res.data.metadata ?? []
      setAvailableNetworks(items)
      setSelectedNetwork((prev) => prev || items[0]?.name || '')
    } catch {
      setAvailableNetworks([])
    } finally {
      setLoadingNetworks(false)
    }
  }, [])

  const addNetworkInterface = useCallback(() => {
    if (!selectedNetwork) return
    setSettingsForm((prev) => ({
      ...prev,
      networks: [
        ...prev.networks,
        {
          device: buildDefaultDeviceName(prev.networks.length),
          network: selectedNetwork,
        },
      ],
    }))
  }, [selectedNetwork])

  const removeNetworkInterface = useCallback((index: number) => {
    setSettingsForm((prev) => {
      const next = prev.networks.filter((_, i) => i !== index)
      return {
        ...prev,
        networks: next.map((item, i) => ({
          ...item,
          device: item.device || buildDefaultDeviceName(i),
        })),
      }
    })
  }, [])

  const saveSettings = useCallback(async () => {
    if (!instance) return

    const cpuValue = parsePositiveInt(settingsForm.cpu)
    const memoryValue = parsePositiveInt(settingsForm.memoryMB)
    const diskValue = parsePositiveInt(settingsForm.diskGB)

    if (!cpuValue || !memoryValue || !diskValue) {
      setSettingsError('CPU, memory, and disk size must be positive numbers.')
      return
    }

    setSettingsBusy(true)
    setSettingsError(null)
    setSettingsSuccess(null)

    try {
      const devices = settingsForm.networks.reduce<Record<string, Record<string, string>>>((acc, item, idx) => {
        const deviceName = item.device.trim() || buildDefaultDeviceName(idx)
        if (item.network.trim()) {
          acc[deviceName] = {
            type: 'nic',
            name: deviceName,
            network: item.network.trim(),
          }
        }
        return acc
      }, {})

      devices.root = {
        type: 'disk',
        path: '/',
        size: `${diskValue}GB`,
      }

      const payload: LXDPatchInstanceRequest = {
        config: {
          'limits.cpu': String(cpuValue),
          'limits.memory': `${memoryValue}MB`,
          'limits.disk': `${diskValue}GB`,
          'boot.autostart': String(settingsForm.autostart),
          'security.nesting': String(settingsForm.nested),
          'user.caker.suspendable': String(settingsForm.suspendable),
          'user.caker.dynamic_port_forwarding': String(settingsForm.dynamicPortForwarding),
        },
        devices,
      }

      await patchInstance(instance.name, payload)
      await refreshInstanceData()
      setSettingsSuccess('Settings updated successfully.')
    } catch (e) {
      setSettingsError(String(e))
    } finally {
      setSettingsBusy(false)
    }
  }, [instance, refreshInstanceData, settingsForm])

  // ── Open terminal session ──────────────────────────────────────────────────
  const openTerminal = useCallback(async () => {
    if (!name || termRequested.current || termSession) return
    termRequested.current = true
    setSessionError(null)
    setSessionLoading(true)
    try {
      const res = await execInstance(name, ['sh'])
      const meta = res.data.metadata
      termReconnectRequested.current = false
      setTermSession({ operationId: meta.id, fds: meta.metadata.fds })
    } catch (e: unknown) {
      termRequested.current = false
      setSessionError(
        (e as { response?: { data?: { error?: string } } })?.response?.data?.error ?? String(e),
      )
    } finally {
      setSessionLoading(false)
    }
  }, [name, termSession])

  const handleTerminalDisconnected = useCallback(() => {
    termRequested.current = false
    setTermSession(null)

    if (shouldRetryVGAReconnect(instance?.status)) {
      termReconnectRequested.current = true
    }
  }, [instance?.status])

  useEffect(() => {
    if (activeTab !== 'terminal' || !termReconnectRequested.current || termSession || termRequested.current) {
      return
    }

    if (instance?.status === 'Running') {
      openTerminal()
      return
    }

    if (!shouldRetryVGAReconnect(instance?.status)) {
      termReconnectRequested.current = false
    }
  }, [activeTab, instance?.status, openTerminal, termSession])

  // ── Open VGA session ───────────────────────────────────────────────────────
  const openVGA = useCallback(async () => {
    if (!name || vgaRequested.current || vgaSession) return
    vgaRequested.current = true
    setSessionError(null)
    setSessionLoading(true)
    try {
      const res = await consoleInstance(name, 'vga')
      const meta = res.data.metadata
      vgaReconnectRequested.current = false
      setVgaSession({ operationId: meta.id, fds: meta.metadata.fds })
    } catch (e: unknown) {
      vgaRequested.current = false
      setSessionError(
        (e as { response?: { data?: { error?: string } } })?.response?.data?.error ?? String(e),
      )
    } finally {
      setSessionLoading(false)
    }
  }, [name, vgaSession])

  const handleVGADisconnected = useCallback(() => {
    vgaRequested.current = false
    setVgaSession(null)

    if (shouldRetryVGAReconnect(instance?.status)) {
      vgaReconnectRequested.current = true
    }
  }, [instance?.status])

  useEffect(() => {
    if (activeTab !== 'vga' || !vgaReconnectRequested.current || vgaSession || vgaRequested.current) {
      return
    }

    if (instance?.status === 'Running') {
      openVGA()
      return
    }

    if (!shouldRetryVGAReconnect(instance?.status)) {
      vgaReconnectRequested.current = false
    }
  }, [activeTab, instance?.status, openVGA, vgaSession])

  // ── Load logs ──────────────────────────────────────────────────────────────
  const loadLogs = useCallback(async () => {
    if (!name || logsRequested.current) return
    logsRequested.current = true
    setLogsError(null)
    setLogsLoading(true)
    try {
      const res = await getInstanceLogs(name)
      setLogs(res.data.metadata)
      if (res.data.metadata.length > 0) {
        setSelectedLog(res.data.metadata[0])
      }
    } catch (e: unknown) {
      logsRequested.current = false
      setLogsError(String(e))
    } finally {
      setLogsLoading(false)
    }
  }, [name])

  // ── Load log file content ──────────────────────────────────────────────────
  const loadLogContent = useCallback(async (logFile: string) => {
    if (!name) return
    setSelectedLog(logFile)
    setLogContent(null)
    setLogContentError(null)
    setLogContentLoading(true)
    try {
      const res = await getInstanceLogFile(name, logFile)
      setLogContent(res.data)
    } catch (e: unknown) {
      setLogContentError(String(e))
    } finally {
      setLogContentLoading(false)
    }
  }, [name])

  // ── Tab switch side-effects ────────────────────────────────────────────────
  useEffect(() => {
    if (activeTab === 'terminal' && isRunning && !termSession) openTerminal()
    if (activeTab === 'vga' && isRunning && !vgaSession) openVGA()
    if (activeTab === 'logs' && logs.length === 0 && !logsLoading) loadLogs()
    if (activeTab === 'settings' && availableNetworks.length === 0 && !loadingNetworks) loadAvailableNetworks()
  }, [
    activeTab,
    isRunning,
    termSession,
    vgaSession,
    logs.length,
    logsLoading,
    availableNetworks.length,
    loadingNetworks,
    openTerminal,
    openVGA,
    loadLogs,
    loadAvailableNetworks,
  ])

  useEffect(() => {
    if (activeTab !== 'vga') {
      vgaRequested.current = false
      vgaReconnectRequested.current = false
      setVgaSession(null)
    }
  }, [activeTab])

  useEffect(() => {
    if (activeTab !== 'terminal') {
      termRequested.current = false
      termReconnectRequested.current = false
      setTermSession(null)
    }
  }, [activeTab])

  // ─────────────────────────────────────────────────────────────────────────
  if (!instance && !loadError) return <PageSpinner />

  if (loadError) {
    return (
      <div className="p-4">
        <div className="alert alert-danger">{loadError}</div>
        <Link to="/instances" className="btn btn-secondary btn-sm">
          <i className="bi bi-arrow-left me-1" />
          Back
        </Link>
      </div>
    )
  }

  const tabClass = (t: ActiveTab) =>
    `nav-link ${activeTab === t ? 'active' : ''}`

  return (
    <div className="d-flex flex-column" style={{ position: 'absolute', inset: 0 }}>
      {/* ── Header ─────────────────────────────────────────────────────────── */}
      <div className="px-4 pt-3 pb-0 border-bottom bg-white flex-shrink-0">
        <div className="d-flex align-items-center gap-3 mb-3">
          <Link to="/instances" className="btn btn-sm btn-outline-secondary">
            <i className="bi bi-arrow-left" />
          </Link>
          <div>
            <h5 className="mb-0 fw-semibold d-flex align-items-center gap-2">
              <i className="bi bi-display text-primary" />
              {instance!.name}
            </h5>
            <small className="text-muted">{instance!.type}</small>
          </div>
          <div className="ms-2">
            <StatusBadge status={instance!.status} />
          </div>

          {/* Start/Stop actions */}
          {instance && (
            <div className="ms-3 d-flex gap-2 align-items-center">
              {instance.status !== 'Running' && (
                <button
                  className="btn btn-outline-success btn-sm"
                  disabled={actionBusy !== null}
                  title="Start VM"
                  onClick={() => doStateChange('start')}
                >
                  {actionBusy === 'start' ? (
                    <span className="spinner-border spinner-border-sm" />
                  ) : (
                    <><i className="bi bi-play-fill me-1" />Start</>
                  )}
                </button>
              )}
              {instance.status === 'Running' && (
                <button
                  className="btn btn-outline-secondary btn-sm"
                  disabled={actionBusy !== null}
                  title="Stop VM"
                  onClick={() => doStateChange('stop')}
                >
                  {actionBusy === 'stop' ? (
                    <span className="spinner-border spinner-border-sm" />
                  ) : (
                    <><i className="bi bi-stop-fill me-1" />Stop</>
                  )}
                </button>
              )}
              <button
                className="btn btn-outline-danger btn-sm"
                disabled={actionBusy !== null || instance.status === 'Running'}
                title={instance.status === 'Running' ? 'Stop VM before deleting' : 'Delete VM'}
                onClick={doDelete}
              >
                {actionBusy === 'delete' ? (
                  <span className="spinner-border spinner-border-sm" />
                ) : (
                  <><i className="bi bi-trash me-1" />Delete</>
                )}
              </button>
            </div>
          )}
        </div>

        {/* ── Tabs ─────────────────────────────────────────────────────────── */}
        <ul className="nav nav-tabs border-0">
          <li className="nav-item">
            <button className={tabClass('overview')} onClick={() => setActiveTab('overview')}>
              <i className="bi bi-info-circle me-1" />
              Overview
            </button>
          </li>
          <li className="nav-item">
            <button
              className={tabClass('terminal')}
              onClick={() => setActiveTab('terminal')}
              title={!isRunning ? 'Instance must be running' : undefined}
            >
              <i className="bi bi-terminal me-1" />
              Terminal
            </button>
          </li>
          <li className="nav-item">
            <button
              className={tabClass('vga')}
              onClick={() => setActiveTab('vga')}
              title={!isRunning ? 'Instance must be running' : undefined}
            >
              <i className="bi bi-display me-1" />
              VGA Console
            </button>
          </li>
          <li className="nav-item">
            <button className={tabClass('logs')} onClick={() => setActiveTab('logs')}>
              <i className="bi bi-file-text me-1" />
              Logs
            </button>
          </li>
          <li className="nav-item">
            <button className={tabClass('settings')} onClick={() => setActiveTab('settings')}>
              <i className="bi bi-sliders me-1" />
              Settings
            </button>
          </li>
        </ul>
      </div>

      {/* ── Tab content ────────────────────────────────────────────────────── */}
      <div className="flex-grow-1 overflow-hidden" style={{ minHeight: 0 }}>
        {/* Overview */}
        <div
          style={{ display: activeTab === 'overview' ? 'block' : 'none', height: '100%', overflowY: 'auto' }}
        >
          <OverviewPanel instance={instance!} state={state} />
        </div>

        {/* Terminal */}
        <div
          style={{ display: activeTab === 'terminal' ? 'flex' : 'none', height: '100%', flexDirection: 'column' }}
        >
          {!isRunning ? (
            <NotRunningPlaceholder label="terminal" />
          ) : sessionLoading && !termSession ? (
            <ConsoleLoading />
          ) : sessionError && !termSession ? (
            <div className="p-4">
              <div className="alert alert-danger d-flex align-items-center gap-2">
                <i className="bi bi-exclamation-triangle-fill" />
                {sessionError}
              </div>
              <button
                className="btn btn-sm btn-outline-primary"
                onClick={() => { termRequested.current = false; openTerminal() }}
              >
                <i className="bi bi-arrow-clockwise me-1" />
                Retry
              </button>
            </div>
          ) : termSession ? (
            <div style={{ flex: 1, minHeight: 0, padding: 12 }}>
              <TerminalConsole
                operationId={termSession.operationId}
                fds={termSession.fds}
                isActive={activeTab === 'terminal'}
                onDisconnected={handleTerminalDisconnected}
              />
            </div>
          ) : null}
        </div>

        {/* VGA Console */}
        <div
          style={{ display: activeTab === 'vga' ? 'flex' : 'none', height: '100%', flexDirection: 'column' }}
        >
          {!isRunning ? (
            <NotRunningPlaceholder label="VGA console" />
          ) : sessionLoading && !vgaSession ? (
            <ConsoleLoading />
          ) : sessionError && !vgaSession ? (
            <div className="p-4">
              <div className="alert alert-danger d-flex align-items-center gap-2">
                <i className="bi bi-exclamation-triangle-fill" />
                {sessionError}
              </div>
              <button
                className="btn btn-sm btn-outline-primary"
                onClick={() => { vgaRequested.current = false; openVGA() }}
              >
                <i className="bi bi-arrow-clockwise me-1" />
                Retry
              </button>
            </div>
          ) : vgaSession ? (
            <>
              <div className="d-flex justify-content-end align-items-center" style={{ padding: '0 12px 8px 12px' }}>
                <button
                  className="btn btn-outline-secondary rounded-circle shadow"
                  style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  title="Plein écran"
                  onClick={() => vgaConsoleRef.current?.toggleFullScreen()}
                >
                  <i className="bi bi-arrows-fullscreen fs-5" />
                </button>
              </div>
              <div style={{ flex: 1, minHeight: 0, padding: 12 }}>
                {activeTab === 'vga' ? (
                  <VGAConsole
                    ref={vgaConsoleRef}
                    operationId={vgaSession.operationId}
                    fds={vgaSession.fds}
                    onDisconnected={handleVGADisconnected}
                  />
                ) : null}
              </div>
            </>
          ) : null}
        </div>

        {/* Logs */}
        <div
          style={{ display: activeTab === 'logs' ? 'flex' : 'none', height: '100%', flexDirection: 'column' }}
        >
          {logsLoading && logs.length === 0 ? (
            <ConsoleLoading />
          ) : logsError && logs.length === 0 ? (
            <div className="p-4">
              <div className="alert alert-danger d-flex align-items-center gap-2">
                <i className="bi bi-exclamation-triangle-fill" />
                {logsError}
              </div>
              <button
                className="btn btn-sm btn-outline-primary"
                onClick={() => { logsRequested.current = false; loadLogs() }}
              >
                <i className="bi bi-arrow-clockwise me-1" />
                Retry
              </button>
            </div>
          ) : (
            <div style={{ flex: 1, minHeight: 0 }}>
              <LogsPanel
                logs={logs}
                selectedLog={selectedLog}
                onLogSelect={loadLogContent}
                logContent={logContent}
                loading={logContentLoading}
                error={logContentError}
              />
            </div>
          )}
        </div>

        {/* Settings */}
        <div
          style={{ display: activeTab === 'settings' ? 'block' : 'none', height: '100%', overflowY: 'auto' }}
        >
          <div className="p-4" style={{ maxWidth: 980 }}>
            <div className="card border-0 shadow-sm">
              <div className="card-header bg-transparent d-flex justify-content-between align-items-center">
                <span className="fw-semibold">
                  <i className="bi bi-sliders me-2 text-primary" />
                  VM settings
                </span>
                <button className="btn btn-primary btn-sm" disabled={settingsBusy} onClick={saveSettings}>
                  {settingsBusy ? (
                    <span className="spinner-border spinner-border-sm" />
                  ) : (
                    <><i className="bi bi-check2 me-1" />Save changes</>
                  )}
                </button>
              </div>
              <div className="card-body">
                {settingsError && (
                  <div className="alert alert-danger d-flex align-items-center gap-2">
                    <i className="bi bi-exclamation-triangle-fill" />
                    {settingsError}
                  </div>
                )}
                {settingsSuccess && (
                  <div className="alert alert-success d-flex align-items-center gap-2">
                    <i className="bi bi-check-circle-fill" />
                    {settingsSuccess}
                  </div>
                )}

                <div className="row g-3">
                  <div className="col-md-4">
                    <label className="form-label fw-medium">CPU</label>
                    <input
                      type="number"
                      min={1}
                      className="form-control"
                      value={settingsForm.cpu}
                      onChange={(e) => setSettingsForm((prev) => ({ ...prev, cpu: e.target.value }))}
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-medium">Memory (MB)</label>
                    <input
                      type="number"
                      min={256}
                      step={256}
                      className="form-control"
                      value={settingsForm.memoryMB}
                      onChange={(e) => setSettingsForm((prev) => ({ ...prev, memoryMB: e.target.value }))}
                    />
                  </div>
                  <div className="col-md-4">
                    <label className="form-label fw-medium">Disk (GB)</label>
                    <input
                      type="number"
                      min={1}
                      className="form-control"
                      value={settingsForm.diskGB}
                      onChange={(e) => setSettingsForm((prev) => ({ ...prev, diskGB: e.target.value }))}
                    />
                  </div>
                </div>

                <hr />

                <div className="row g-3">
                  <div className="col-12 col-lg-6">
                    <div className="form-check form-switch mb-2">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="settings-autostart"
                        checked={settingsForm.autostart}
                        onChange={(e) => setSettingsForm((prev) => ({ ...prev, autostart: e.target.checked }))}
                      />
                      <label className="form-check-label" htmlFor="settings-autostart">Autostart</label>
                    </div>
                    <div className="form-check form-switch mb-2">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="settings-nested"
                        checked={settingsForm.nested}
                        onChange={(e) => setSettingsForm((prev) => ({ ...prev, nested: e.target.checked }))}
                      />
                      <label className="form-check-label" htmlFor="settings-nested">Nested virtualization</label>
                    </div>
                    <div className="form-check form-switch mb-2">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="settings-suspendable"
                        checked={settingsForm.suspendable}
                        onChange={(e) => setSettingsForm((prev) => ({ ...prev, suspendable: e.target.checked }))}
                      />
                      <label className="form-check-label" htmlFor="settings-suspendable">Suspendable mode</label>
                    </div>
                    <div className="form-check form-switch">
                      <input
                        className="form-check-input"
                        type="checkbox"
                        id="settings-dpf"
                        checked={settingsForm.dynamicPortForwarding}
                        onChange={(e) => setSettingsForm((prev) => ({ ...prev, dynamicPortForwarding: e.target.checked }))}
                      />
                      <label className="form-check-label" htmlFor="settings-dpf">Dynamic port forwarding</label>
                    </div>
                  </div>
                </div>

                <hr />

                <div>
                  <label className="form-label fw-medium">Network interfaces</label>
                  <div className="d-flex gap-2 mb-2">
                    <select
                      className="form-select form-select-sm"
                      value={selectedNetwork}
                      onChange={(e) => setSelectedNetwork(e.target.value)}
                      disabled={loadingNetworks || availableNetworks.length === 0}
                      style={{ maxWidth: 280 }}
                    >
                      {availableNetworks.map((network) => (
                        <option key={network.name} value={network.name}>{network.name}</option>
                      ))}
                    </select>
                    <button className="btn btn-outline-primary btn-sm" onClick={addNetworkInterface} disabled={!selectedNetwork}>
                      <i className="bi bi-plus-circle me-1" />Add interface
                    </button>
                  </div>

                  {settingsForm.networks.length === 0 ? (
                    <p className="text-muted small mb-0">No network interface configured.</p>
                  ) : (
                    <div className="table-responsive">
                      <table className="table table-sm align-middle mb-0">
                        <thead className="table-light">
                          <tr>
                            <th style={{ width: '35%' }}>Device</th>
                            <th style={{ width: '50%' }}>Network</th>
                            <th style={{ width: '15%' }} />
                          </tr>
                        </thead>
                        <tbody>
                          {settingsForm.networks.map((item, idx) => (
                            <tr key={`${item.device}-${idx}`}>
                              <td>
                                <input
                                  className="form-control form-control-sm"
                                  value={item.device}
                                  onChange={(e) => setSettingsForm((prev) => ({
                                    ...prev,
                                    networks: prev.networks.map((network, i) => i === idx ? { ...network, device: e.target.value } : network),
                                  }))}
                                />
                              </td>
                              <td>
                                <select
                                  className="form-select form-select-sm"
                                  value={item.network}
                                  onChange={(e) => setSettingsForm((prev) => ({
                                    ...prev,
                                    networks: prev.networks.map((network, i) => i === idx ? { ...network, network: e.target.value } : network),
                                  }))}
                                >
                                  {availableNetworks.map((network) => (
                                    <option key={network.name} value={network.name}>{network.name}</option>
                                  ))}
                                </select>
                              </td>
                              <td className="text-end">
                                <button className="btn btn-outline-danger btn-sm" onClick={() => removeNetworkInterface(idx)}>
                                  <i className="bi bi-trash" />
                                </button>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}