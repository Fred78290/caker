import { useCallback, useEffect, useState } from 'react';
import { deleteIdentity, listIdentities } from '../api/auth';
import { ConfirmDialog, openModal } from '../components/ConfirmDialog';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import type { LXDIdentity } from '../types/lxd';

export function IdentitiesPage() {
  const [identities, setIdentities] = useState<LXDIdentity[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<LXDIdentity | null>(null)

  const refresh = useCallback(() => {
    setLoading(true)
    listIdentities()
      .then((r) => setIdentities(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  const doDelete = async () => {
    if (!selected) return
    try {
      await deleteIdentity(selected.authentication_method, selected.id)
      refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setSelected(null)
    }
  }

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Identities"
        subtitle={`${identities.length} identit${identities.length !== 1 ? 'ies' : 'y'}`}
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
                <th>Auth Method</th>
                <th>Name</th>
                <th>ID</th>
                <th>Type</th>
                <th>Groups</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {identities.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-muted py-4">
                    No identities found
                  </td>
                </tr>
              )}
              {identities.map((id) => (
                <tr key={`${id.authentication_method}:${id.id}`}>
                  <td>
                    <span className="badge bg-light text-dark border">
                      {id.authentication_method}
                    </span>
                  </td>
                  <td className="fw-medium">{id.name}</td>
                  <td>
                    <code className="small">{id.id.slice(0, 16)}</code>
                  </td>
                  <td>
                    <small className="text-muted">{id.type}</small>
                  </td>
                  <td>
                    {(id.groups ?? []).map((g) => (
                      <span key={g} className="badge bg-secondary me-1">
                        {g}
                      </span>
                    ))}
                  </td>
                  <td className="text-end">
                    <button
                      className="btn btn-sm btn-outline-danger"
                      onClick={() => {
                        setSelected(id)
                        openModal('confirmDeleteIdentity')
                      }}
                    >
                      <i className="bi bi-trash" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <ConfirmDialog
        id="confirmDeleteIdentity"
        title="Delete Identity"
        message={`Are you sure you want to delete identity "${selected?.name}"?`}
        onConfirm={doDelete}
      />
    </>
  )
}
