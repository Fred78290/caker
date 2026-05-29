import { useCallback, useEffect, useState } from 'react';
import { createGroup, deleteGroup, listGroups } from '../api/auth';
import { ConfirmDialog, openModal } from '../components/ConfirmDialog';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner, Spinner } from '../components/Spinner';
import type { LXDAuthGroup } from '../types/lxd';

export function GroupsPage() {
  const [groups, setGroups] = useState<LXDAuthGroup[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<LXDAuthGroup | null>(null)
  const [newName, setNewName] = useState('')
  const [creating, setCreating] = useState(false)
  const [deleting, setDeleting] = useState(false)

  const refresh = useCallback(() => {
    setLoading(true)
    listGroups()
      .then((r) => setGroups(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  const doCreate = async () => {
    if (!newName.trim()) return
    setCreating(true)
    try {
      await createGroup(newName.trim())
      setNewName('')
      refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setCreating(false)
    }
  }

  const doDelete = async () => {
    if (!selected) return
    setDeleting(true)
    try {
      await deleteGroup(selected.name)
      refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setDeleting(false)
      setSelected(null)
    }
  }

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Auth Groups"
        subtitle={`${groups.length} group${groups.length !== 1 ? 's' : ''}`}
      />

      {error && (
        <div className="alert alert-danger alert-dismissible">
          {error}
          <button className="btn-close" onClick={() => setError(null)} />
        </div>
      )}

      {/* Create form */}
      <div className="card border-0 shadow-sm mb-4">
        <div className="card-body">
          <div className="input-group" style={{ maxWidth: 400 }}>
            <input
              className="form-control"
              placeholder="New group name"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && doCreate()}
            />
            <button
              className="btn btn-primary"
              disabled={creating || !newName.trim()}
              onClick={doCreate}
            >
              {creating ? <Spinner size="sm" /> : <><i className="bi bi-plus-lg me-1" />Create</>}
            </button>
          </div>
        </div>
      </div>

      <div className="card border-0 shadow-sm">
        <div className="table-responsive">
          <table className="table table-hover mb-0 align-middle">
            <thead className="table-light">
              <tr>
                <th>Name</th>
                <th>Description</th>
                <th>Permissions</th>
                <th>Members</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {groups.length === 0 && (
                <tr>
                  <td colSpan={5} className="text-center text-muted py-4">
                    No groups found
                  </td>
                </tr>
              )}
              {groups.map((g) => (
                <tr key={g.name}>
                  <td className="fw-medium">{g.name}</td>
                  <td>
                    <small className="text-muted">{g.description || '—'}</small>
                  </td>
                  <td>
                    <small className="text-muted">
                      {(g.permissions ?? []).length}
                    </small>
                  </td>
                  <td>
                    <small className="text-muted">
                      {((g.identities?.tls ?? []).length) +
                        ((g.identities?.oidc ?? []).length)}{' '}
                      identit{((g.identities?.tls ?? []).length) + ((g.identities?.oidc ?? []).length) !== 1 ? 'ies' : 'y'}
                    </small>
                  </td>
                  <td className="text-end">
                    <button
                      className="btn btn-sm btn-outline-danger"
                      disabled={deleting}
                      onClick={() => {
                        setSelected(g)
                        openModal('confirmDeleteGroup')
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
        id="confirmDeleteGroup"
        title="Delete Group"
        message={`Are you sure you want to delete group "${selected?.name}"?`}
        onConfirm={doDelete}
      />
    </>
  )
}
