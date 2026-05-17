import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react';
import { createRemote, deleteRemote, listRemotes, updateRemote } from '../api/remotes';
import { ConfirmDialog, openModal } from '../components/ConfirmDialog';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner, Spinner } from '../components/Spinner';
import type { LXDRemote } from '../types/lxd';

function errorMessage(e: unknown): string {
  if (typeof e === 'object' && e !== null) {
    const maybeResponse = e as { response?: { data?: { error?: string } } }
    if (maybeResponse.response?.data?.error) {
      return maybeResponse.response.data.error
    }
  }
  return String(e)
}

export function RemotesPage() {
  const [remotes, setRemotes] = useState<LXDRemote[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionBusy, setActionBusy] = useState<string | null>(null)
  const [selected, setSelected] = useState<LXDRemote | null>(null)
  const [editingName, setEditingName] = useState<string | null>(null)
  const [editRemoteName, setEditRemoteName] = useState('')
  const [editRemoteURL, setEditRemoteURL] = useState('')

  const [name, setName] = useState('')
  const [url, setUrl] = useState('https://images.linuxcontainers.org')

  const canCreate = useMemo(() => name.trim().length > 0 && url.trim().length > 0, [name, url])

  const refresh = useCallback(() => {
    setLoading(true)
    listRemotes()
      .then((r) => setRemotes(r.data.metadata ?? []))
      .catch((e) => setError(errorMessage(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  const onCreate = async (evt: FormEvent) => {
    evt.preventDefault()
    if (!canCreate) return

    setActionBusy('create')
    try {
      await createRemote({ name: name.trim(), url: url.trim() })
      setName('')
      await refresh()
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setActionBusy(null)
    }
  }

  const onDelete = async () => {
    if (!selected) return

    setActionBusy(`delete:${selected.name}`)
    try {
      await deleteRemote(selected.name)
      await refresh()
      setSelected(null)
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setActionBusy(null)
    }
  }

  const beginEdit = (remote: LXDRemote) => {
    setEditingName(remote.name)
    setEditRemoteName(remote.name)
    setEditRemoteURL(remote.url)
  }

  const cancelEdit = () => {
    setEditingName(null)
    setEditRemoteName('')
    setEditRemoteURL('')
  }

  const saveEdit = async () => {
    if (!editingName) return

    setActionBusy(`update:${editingName}`)
    try {
      await updateRemote(editingName, {
        name: editRemoteName.trim(),
        url: editRemoteURL.trim(),
      })
      cancelEdit()
      await refresh()
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setActionBusy(null)
    }
  }

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Remotes"
        subtitle={`${remotes.length} remote${remotes.length !== 1 ? 's' : ''}`}
        actions={
          <button className="btn btn-outline-secondary btn-sm" onClick={refresh} disabled={actionBusy !== null}>
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

      <div className="card border-0 shadow-sm mb-3">
        <div className="card-body">
          <h6 className="fw-semibold mb-3">Add Remote</h6>
          <form className="row g-2" onSubmit={onCreate}>
            <div className="col-md-3">
              <input
                className="form-control"
                placeholder="Name (e.g. images)"
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={actionBusy !== null}
              />
            </div>
            <div className="col-md-7">
              <input
                className="form-control"
                placeholder="https://..."
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                disabled={actionBusy !== null}
              />
            </div>
            <div className="col-md-2 d-grid">
              <button type="submit" className="btn btn-primary" disabled={!canCreate || actionBusy !== null}>
                {actionBusy === 'create' ? <Spinner size="sm" /> : <><i className="bi bi-plus-lg me-1" />Add</>}
              </button>
            </div>
          </form>
        </div>
      </div>

      <div className="card border-0 shadow-sm">
        <div className="table-responsive">
          <table className="table table-hover mb-0 align-middle">
            <thead className="table-light">
              <tr>
                <th>Name</th>
                <th>URL</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {remotes.length === 0 && (
                <tr>
                  <td colSpan={3} className="text-center text-muted py-4">No remotes found</td>
                </tr>
              )}
              {remotes.map((remote) => {
                const isEditing = editingName === remote.name
                const isUpdating = actionBusy === `update:${remote.name}`

                return (
                  <tr key={remote.name}>
                    <td className="fw-medium">
                      {isEditing ? (
                        <input
                          className="form-control form-control-sm"
                          value={editRemoteName}
                          onChange={(e) => setEditRemoteName(e.target.value)}
                          disabled={actionBusy !== null}
                        />
                      ) : remote.name}
                    </td>
                    <td>
                      {isEditing ? (
                        <input
                          className="form-control form-control-sm"
                          value={editRemoteURL}
                          onChange={(e) => setEditRemoteURL(e.target.value)}
                          disabled={actionBusy !== null}
                        />
                      ) : (
                        <code>{remote.url}</code>
                      )}
                    </td>
                    <td className="text-end">
                      {isEditing ? (
                        <div className="btn-group btn-group-sm">
                          <button
                            className="btn btn-success"
                            disabled={actionBusy !== null}
                            onClick={saveEdit}
                          >
                            {isUpdating ? <Spinner size="sm" /> : <><i className="bi bi-check-lg me-1" />Save</>}
                          </button>
                          <button
                            className="btn btn-outline-secondary"
                            disabled={actionBusy !== null}
                            onClick={cancelEdit}
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <div className="btn-group btn-group-sm">
                          <button
                            className="btn btn-outline-primary"
                            disabled={actionBusy !== null}
                            onClick={() => beginEdit(remote)}
                          >
                            <i className="bi bi-pencil me-1" />Edit
                          </button>
                          <button
                            className="btn btn-outline-danger"
                            disabled={actionBusy !== null}
                            onClick={() => {
                              setSelected(remote)
                              openModal('confirmDeleteRemote')
                            }}
                          >
                            <i className="bi bi-trash me-1" />Delete
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      <ConfirmDialog
        id="confirmDeleteRemote"
        title="Delete Remote"
        message={`Are you sure you want to delete "${selected?.name}"?`}
        onConfirm={onDelete}
      />
    </>
  )
}