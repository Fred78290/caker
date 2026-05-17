import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    changeInstanceState,
    deleteInstance,
    listInstances,
} from '../api/instances';
import { waitOperation } from '../api/operations';
import { ConfirmDialog, openModal } from '../components/ConfirmDialog';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner, Spinner } from '../components/Spinner';
import { StatusBadge } from '../components/StatusBadge';
import type { LXDInstance } from '../types/lxd';
import { CreateInstanceModal } from './CreateInstanceModal';

export function InstancesPage() {
  const navigate = useNavigate()
  const [instances, setInstances] = useState<LXDInstance[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionBusy, setActionBusy] = useState<string | null>(null)
  const [selected, setSelected] = useState<LXDInstance | null>(null)

  const refresh = useCallback((showLoader = true) => {
    if (showLoader) setLoading(true)
    listInstances()
      .then((r) => setInstances(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => {
        if (showLoader) setLoading(false)
      })
  }, [])

  useEffect(() => {
    refresh()

    // Keep VM status up to date while the page is open.
    const timer = setInterval(() => refresh(false), 10000)
    return () => clearInterval(timer)
  }, [refresh])

  const doStateChange = async (
    name: string,
    action: 'start' | 'stop' | 'restart',
  ) => {
    setActionBusy(name + ':' + action)
    try {
      await changeInstanceState(name, action)
      setTimeout(() => refresh(false), 1500)
    } catch (e) {
      setError(String(e))
    } finally {
      setActionBusy(null)
    }
  }

  const doDelete = async () => {
    if (!selected) return
    setActionBusy(selected.name + ':delete')
    try {
      const response = await deleteInstance(selected.name)
      const operationId = response.data.operation.split('/').filter(Boolean).pop()

      if (operationId) {
        const completed = await waitOperation(operationId, 60)
        if (completed.data.metadata.status !== 'Success') {
          throw new Error(completed.data.metadata.error || 'Delete operation failed')
        }
      }

      refresh(false)
    } catch (e) {
      setError(String(e))
    } finally {
      setActionBusy(null)
      setSelected(null)
    }
  }

  const busy = (name: string, action: string) =>
    actionBusy === `${name}:${action}`

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Instances"
        subtitle={`${instances.length} virtual machine${instances.length !== 1 ? 's' : ''}`}
        actions={
          <button
            className="btn btn-primary btn-sm"
            data-bs-toggle="modal"
            data-bs-target="#createInstanceModal"
          >
            <i className="bi bi-plus-lg me-1" />
            New Instance
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
                <th>Profiles</th>
                <th>Description</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {instances.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-muted py-4">
                    No instances found
                  </td>
                </tr>
              )}
              {instances.map((inst) => (
                <tr
                  key={inst.name}
                  style={{ cursor: 'pointer' }}
                  onClick={() => navigate(`/instances/${inst.name}`)}
                >
                  <td className="fw-medium">
                    {inst.name}
                  </td>
                  <td>
                    <span className="badge bg-light text-dark border">
                      <i
                        className={`bi me-1 ${inst.type === 'container' ? 'bi-box' : 'bi-display'}`}
                      />
                      {inst.type}
                    </span>
                  </td>
                  <td>
                    <StatusBadge status={inst.status} />
                  </td>
                  <td>
                    <small className="text-muted">
                      {inst.profiles.join(', ') || '—'}
                    </small>
                  </td>
                  <td>
                    <small className="text-muted">
                      {inst.description || '—'}
                    </small>
                  </td>
                  <td className="text-end">
                    <div className="btn-group btn-group-sm">
                      {inst.status !== 'Running' && (
                        <button
                          className="btn btn-outline-success"
                          title="Start"
                          disabled={actionBusy !== null}
                          onClick={(e) => {
                            e.stopPropagation()
                            doStateChange(inst.name, 'start')
                          }}
                        >
                          {busy(inst.name, 'start') ? (
                            <Spinner size="sm" />
                          ) : (
                            <i className="bi bi-play-fill" />
                          )}
                        </button>
                      )}
                      {inst.status === 'Running' && (
                        <>
                          <button
                            className="btn btn-outline-warning"
                            title="Restart"
                            disabled={actionBusy !== null}
                            onClick={(e) => {
                              e.stopPropagation()
                              doStateChange(inst.name, 'restart')
                            }}
                          >
                            {busy(inst.name, 'restart') ? (
                              <Spinner size="sm" />
                            ) : (
                              <i className="bi bi-arrow-clockwise" />
                            )}
                          </button>
                          <button
                            className="btn btn-outline-secondary"
                            title="Stop"
                            disabled={actionBusy !== null}
                            onClick={(e) => {
                              e.stopPropagation()
                              doStateChange(inst.name, 'stop')
                            }}
                          >
                            {busy(inst.name, 'stop') ? (
                              <Spinner size="sm" />
                            ) : (
                              <i className="bi bi-stop-fill" />
                            )}
                          </button>
                        </>
                      )}
                      <button
                        className="btn btn-outline-danger"
                        title="Delete"
                        disabled={actionBusy !== null}
                        onClick={(e) => {
                          e.stopPropagation()
                          setSelected(inst)
                          openModal('confirmDeleteInstance')
                        }}
                      >
                        <i className="bi bi-trash" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <ConfirmDialog
        id="confirmDeleteInstance"
        title="Delete Instance"
        message={`Are you sure you want to delete "${selected?.name}"? This cannot be undone.`}
        onConfirm={doDelete}
      />

      <CreateInstanceModal
        onCreated={() => setTimeout(() => refresh(false), 2000)}
        onClose={() => setTimeout(() => refresh(false), 500)}
      />
    </>
  )
}
