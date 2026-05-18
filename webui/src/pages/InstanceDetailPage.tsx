import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { changeInstanceState, consoleInstance, deleteInstance, execInstance, getInstance, getInstanceLogFile, getInstanceLogs, getInstanceState } from '../api/instances';
import { PageSpinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import { TerminalConsole } from '../components/TerminalConsole';
import { VGAConsole } from '../components/VGAConsole';
import type { LXDInstance, LXDInstanceState } from '../types/lxd';
import { eventBus } from '../utils/eventBus';

type ActiveTab = 'overview' | 'terminal' | 'vga' | 'logs'

interface ConsoleSession {
  operationId: string
  fds: Record<string, string>
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
      {Object.keys(instance.config ?? {}).length > 0 && (
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
                  {Object.entries(instance.config).map(([k, v]) => (
                    <tr key={k}>
                      <td><code className="small">{k}</code></td>
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

  // Track which sessions have been requested to avoid duplicate calls.
  const termRequested = useRef(false)
  const vgaRequested = useRef(false)
  const logsRequested = useRef(false)

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

  // ── Open terminal session ──────────────────────────────────────────────────
  const openTerminal = useCallback(async () => {
    if (!name || termRequested.current || termSession) return
    termRequested.current = true
    setSessionError(null)
    setSessionLoading(true)
    try {
      const res = await execInstance(name, ['sh'])
      const meta = res.data.metadata
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

  // ── Open VGA session ───────────────────────────────────────────────────────
  const openVGA = useCallback(async () => {
    if (!name || vgaRequested.current || vgaSession) return
    vgaRequested.current = true
    setSessionError(null)
    setSessionLoading(true)
    try {
      const res = await consoleInstance(name, 'vga')
      const meta = res.data.metadata
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
    if (vgaSession) {
      vgaRequested.current = false
      setVgaSession(null)
    }
  }, [])

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
  }, [activeTab, isRunning, termSession, vgaSession, logs.length, logsLoading, openTerminal, openVGA, loadLogs])

  useEffect(() => {
    if (activeTab !== 'vga') {
      vgaRequested.current = false
      setVgaSession(null)
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
            <div style={{ flex: 1, minHeight: 0, padding: 12 }}>
              {activeTab === 'vga' ? (
                <VGAConsole
                  operationId={vgaSession.operationId}
                  fds={vgaSession.fds}
                  onDisconnected={handleVGADisconnected}
                />
              ) : null}
            </div>
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
      </div>
    </div>
  )
}
