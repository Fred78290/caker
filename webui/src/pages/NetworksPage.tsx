import { useCallback, useEffect, useState } from 'react';
import { listNetworks } from '../api/networks';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import type { LXDNetwork } from '../types/lxd';

export function NetworksPage() {
  const [networks, setNetworks] = useState<LXDNetwork[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(() => {
    setLoading(true)
    listNetworks()
      .then((r) => setNetworks((r.data.metadata ?? []).filter((net) => net.name !== 'imds')))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Networks"
        subtitle={`${networks.length} network${networks.length !== 1 ? 's' : ''}`}
        actions={
          <button className="btn btn-outline-secondary btn-sm" onClick={refresh}>
            <i className="bi bi-arrow-clockwise me-1" />
            Refresh
          </button>
        }
      />

      {error && (
        <div className="alert alert-danger alert-dismissible">
          {error}
          <button className="btn-close" onClick={() => setError(null)} />
        </div>
      )}

      <div className="card border-0 shadow-sm">
        <div className="table-responsive">
          <table className="table table-hover mb-0 align-middle">
            <thead className="table-light">
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Status</th>
                <th>Managed</th>
                <th>Used by</th>
              </tr>
            </thead>
            <tbody>
              {networks.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-muted py-4">
                    No networks found
                  </td>
                </tr>
              )}
              {networks.map((net) => (
                <tr key={net.name}>
                  <td className="fw-medium">{net.name}</td>
                  <td>
                    <span className="badge bg-light text-dark border">{net.type}</span>
                  </td>
                  <td>
                    <StatusBadge status={net.status || 'Unknown'} />
                  </td>
                  <td>
                    {net.managed ? (
                      <i className="bi bi-check-circle text-success" />
                    ) : (
                      <i className="bi bi-dash text-muted" />
                    )}
                  </td>
                  <td>
                    <small className="text-muted">
                      {(net.used_by ?? []).length} instance
                      {(net.used_by ?? []).length !== 1 ? 's' : ''}
                    </small>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
