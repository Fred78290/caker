import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { listImages } from '../api/images';
import { listInstances } from '../api/instances';
import { listNetworks } from '../api/networks';
import { listOperations } from '../api/operations';
import { getServerInfo } from '../api/server';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import type { LXDInstance, LXDOperation, LXDServerInfo } from '../types/lxd';

interface Stats {
  instances: LXDInstance[]
  imageCount: number
  networkCount: number
  recentOps: LXDOperation[]
  server: LXDServerInfo | null
}

function StatCard({
  icon,
  label,
  value,
  to,
  color = 'primary',
}: {
  icon: string
  label: string
  value: number | string
  to: string
  color?: string
}) {
  return (
    <Link to={to} className="text-decoration-none">
      <div className={`card border-0 shadow-sm h-100`}>
        <div className="card-body d-flex align-items-center gap-3">
          <div
            className={`rounded-circle bg-${color} bg-opacity-10 d-flex align-items-center justify-content-center`}
            style={{ width: 52, height: 52 }}
          >
            <i className={`bi bi-${icon} fs-4 text-${color}`} />
          </div>
          <div>
            <div className="fs-2 fw-bold lh-1">{value}</div>
            <small className="text-muted">{label}</small>
          </div>
        </div>
      </div>
    </Link>
  )
}

export function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    Promise.all([
      getServerInfo(),
      listInstances(),
      listImages(),
      listNetworks(),
      listOperations(),
    ])
      .then(([serverRes, instRes, imgRes, netRes, opsRes]) => {
        setStats({
          server: serverRes.data.metadata,
          instances: instRes.data.metadata ?? [],
          imageCount: (imgRes.data.metadata ?? []).length,
          networkCount: (netRes.data.metadata ?? []).length,
          recentOps: (opsRes.data.metadata ?? []).slice(0, 5),
        })
      })
      .catch((e) => setError(String(e)))
  }, [])

  if (error)
    return <div className="alert alert-danger">{error}</div>
  if (!stats) return <PageSpinner />

  const running = stats.instances.filter((i) => i.status === 'Running').length
  const stopped = stats.instances.filter((i) => i.status === 'Stopped').length

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle={
          stats.server
            ? `${stats.server.environment.server_name} — caked ${stats.server.environment.server_version}`
            : undefined
        }
      />

      {/* Stats row */}
      <div className="row g-3 mb-4">
        <div className="col-6 col-md-3">
          <StatCard
            icon="hdd-stack"
            label="Instances"
            value={stats.instances.length}
            to="/instances"
            color="primary"
          />
        </div>
        <div className="col-6 col-md-3">
          <StatCard
            icon="layers"
            label="Images"
            value={stats.imageCount}
            to="/images"
            color="info"
          />
        </div>
        <div className="col-6 col-md-3">
          <StatCard
            icon="diagram-3"
            label="Networks"
            value={stats.networkCount}
            to="/networks"
            color="success"
          />
        </div>
        <div className="col-6 col-md-3">
          <StatCard
            icon="clock-history"
            label="Operations"
            value={stats.recentOps.length}
            to="/operations"
            color="warning"
          />
        </div>
      </div>

      <div className="row g-3">
        {/* Instance status breakdown */}
        <div className="col-md-6">
          <div className="card border-0 shadow-sm">
            <div className="card-header bg-white fw-semibold">
              <i className="bi bi-hdd-stack me-2 text-primary" />
              Instance Status
            </div>
            <div className="card-body">
              <div className="d-flex gap-3">
                <div className="text-center px-4">
                  <div className="fs-3 fw-bold text-success">{running}</div>
                  <small className="text-muted">Running</small>
                </div>
                <div className="vr" />
                <div className="text-center px-4">
                  <div className="fs-3 fw-bold text-secondary">{stopped}</div>
                  <small className="text-muted">Stopped</small>
                </div>
                <div className="vr" />
                <div className="text-center px-4">
                  <div className="fs-3 fw-bold">{stats.instances.length}</div>
                  <small className="text-muted">Total</small>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Recent operations */}
        <div className="col-md-6">
          <div className="card border-0 shadow-sm">
            <div className="card-header bg-white fw-semibold">
              <i className="bi bi-clock-history me-2 text-warning" />
              Recent Operations
            </div>
            <ul className="list-group list-group-flush">
              {stats.recentOps.length === 0 && (
                <li className="list-group-item text-muted small">No operations</li>
              )}
              {stats.recentOps.map((op) => (
                <li
                  key={op.id}
                  className="list-group-item d-flex justify-content-between align-items-center"
                >
                  <span className="small text-truncate me-2">{op.description}</span>
                  <span
                    className={`badge bg-${op.status === 'Success' ? 'success' : op.status === 'Failure' ? 'danger' : 'warning'}`}
                  >
                    {op.status}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Server info */}
        {stats.server && (
          <div className="col-12">
            <div className="card border-0 shadow-sm">
              <div className="card-header bg-white fw-semibold">
                <i className="bi bi-info-circle me-2 text-info" />
                Server Info
              </div>
              <div className="card-body">
                <div className="row g-2 small">
                  {[
                    ['Driver', `${stats.server.environment.driver} ${stats.server.environment.driver_version}`],
                    ['Kernel', `${stats.server.environment.kernel} ${stats.server.environment.kernel_version}`],
                    ['API Version', stats.server.api_version],
                    ['Status', stats.server.api_status],
                    ['Architectures', stats.server.environment.architectures.join(', ')],
                  ].map(([k, v]) => (
                    <div key={k} className="col-6 col-md-4">
                      <span className="text-muted">{k}: </span>
                      <span className="fw-medium">{v}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
