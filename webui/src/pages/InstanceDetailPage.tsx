import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { consoleInstance, execInstance, getInstance, getInstanceState } from '../api/instances';
import { PageSpinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import { TerminalConsole } from '../components/TerminalConsole';
import { VGAConsole } from '../components/VGAConsole';
import type { LXDInstance, LXDInstanceState } from '../types/lxd';

type ActiveTab = 'overview' | 'terminal' | 'vga'

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

// ─── Main page ────────────────────────────────────────────────────────────────

export function InstanceDetailPage() {
  const { name } = useParams<{ name: string }>()
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

  // Track which sessions have been requested to avoid duplicate calls.
  const termRequested = useRef(false)
  const vgaRequested = useRef(false)

  // ── Load instance info ─────────────────────────────────────────────────────
  useEffect(() => {
    if (!name) return
    Promise.all([
      getInstance(name).then((r) => setInstance(r.data.metadata)),
      getInstanceState(name)
        .then((r) => setState(r.data.metadata))
        .catch(() => setState(null)),
    ]).catch((e) => setLoadError(String(e)))
  }, [name])

  const isRunning = instance?.status === 'Running'

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

  // ── Tab switch side-effects ────────────────────────────────────────────────
  useEffect(() => {
    if (activeTab === 'terminal' && isRunning && !termSession) openTerminal()
    if (activeTab === 'vga' && isRunning && !vgaSession) openVGA()
  }, [activeTab, isRunning, termSession, vgaSession, openTerminal, openVGA])

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
    <div className="d-flex flex-column" style={{ height: '100%' }}>
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
            <TerminalConsole operationId={termSession.operationId} fds={termSession.fds} />
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
            <VGAConsole operationId={vgaSession.operationId} fds={vgaSession.fds} />
          ) : null}
        </div>
      </div>
    </div>
  )
}
