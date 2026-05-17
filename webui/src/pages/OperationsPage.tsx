import { useCallback, useEffect, useState } from 'react';
import { cancelOperation, listOperations } from '../api/operations';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner, Spinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import type { LXDOperation } from '../types/lxd';

export function OperationsPage() {
  const [operations, setOperations] = useState<LXDOperation[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [cancelling, setCancelling] = useState<string | null>(null)

  const refresh = useCallback((showLoader = true) => {
    if (showLoader) setLoading(true)
    listOperations()
      .then((r) => setOperations(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => {
        if (showLoader) setLoading(false)
      })
  }, [])

  useEffect(() => {
    refresh()

    // Keep operations status up to date while the page is open.
    const timer = setInterval(() => refresh(false), 30000)
    return () => clearInterval(timer)
  }, [refresh])

  const doCancel = async (id: string) => {
    setCancelling(id)
    try {
      await cancelOperation(id)
      refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setCancelling(null)
    }
  }

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Operations"
        subtitle={`${operations.length} operation${operations.length !== 1 ? 's' : ''}`}
        actions={
          <button className="btn btn-outline-secondary btn-sm" onClick={() => refresh()}>
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
                <th>ID</th>
                <th>Description</th>
                <th>Type</th>
                <th>Status</th>
                <th>Created</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {operations.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-muted py-4">
                    No operations found
                  </td>
                </tr>
              )}
              {operations.map((op) => (
                <tr key={op.id}>
                  <td>
                    <code className="small">{op.id.slice(0, 8)}</code>
                  </td>
                  <td>
                    <small>{op.description}</small>
                  </td>
                  <td>
                    <span className="badge bg-light text-dark border">{op.type}</span>
                  </td>
                  <td>
                    <StatusBadge status={op.status} />
                  </td>
                  <td>
                    <small className="text-muted">
                      {op.created_at
                        ? new Date(op.created_at).toLocaleString()
                        : '—'}
                    </small>
                  </td>
                  <td className="text-end">
                    {op.may_cancel && op.status === 'Running' && (
                      <button
                        className="btn btn-sm btn-outline-warning"
                        disabled={cancelling !== null}
                        onClick={() => doCancel(op.id)}
                      >
                        {cancelling === op.id ? (
                          <Spinner size="sm" />
                        ) : (
                          'Cancel'
                        )}
                      </button>
                    )}
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
