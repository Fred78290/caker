import { useState } from 'react';
import { createInstance } from '../api/instances';
import { Spinner } from '../components/Spinner';

interface Props {
  onCreated: () => void
}

export function CreateInstanceModal({ onCreated }: Props) {
  const [name, setName] = useState('')
  const [alias, setAlias] = useState('ubuntu/22.04')
  const [type, setType] = useState<'virtual-machine' | 'container'>('virtual-machine')
  const [description, setDescription] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleSubmit = async () => {
    if (!name.trim()) return
    setBusy(true)
    setError(null)
    try {
      await createInstance({
        name: name.trim(),
        type,
        description,
        source: { type: 'image', alias },
      })
      // Reset form
      setName('')
      setAlias('ubuntu/22.04')
      setDescription('')
      // Close modal
      const el = document.getElementById('createInstanceModal')
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const m = (window as any).bootstrap?.Modal?.getInstance(el)
      m?.hide()
      onCreated()
    } catch (e) {
      setError(String(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div
      className="modal fade"
      id="createInstanceModal"
      tabIndex={-1}
      aria-hidden="true"
    >
      <div className="modal-dialog">
        <div className="modal-content">
          <div className="modal-header">
            <h5 className="modal-title">New Instance</h5>
            <button
              type="button"
              className="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
            />
          </div>
          <div className="modal-body">
            {error && <div className="alert alert-danger">{error}</div>}
            <div className="mb-3">
              <label className="form-label fw-medium">Name</label>
              <input
                className="form-control"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="my-vm"
              />
            </div>
            <div className="mb-3">
              <label className="form-label fw-medium">Type</label>
              <select
                className="form-select"
                value={type}
                onChange={(e) =>
                  setType(e.target.value as 'virtual-machine' | 'container')
                }
              >
                <option value="virtual-machine">Virtual Machine</option>
                <option value="container">Container</option>
              </select>
            </div>
            <div className="mb-3">
              <label className="form-label fw-medium">Image alias</label>
              <input
                className="form-control"
                value={alias}
                onChange={(e) => setAlias(e.target.value)}
                placeholder="ubuntu/22.04"
              />
            </div>
            <div className="mb-3">
              <label className="form-label fw-medium">Description</label>
              <input
                className="form-control"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Optional"
              />
            </div>
          </div>
          <div className="modal-footer">
            <button
              type="button"
              className="btn btn-secondary"
              data-bs-dismiss="modal"
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy || !name.trim()}
              onClick={handleSubmit}
            >
              {busy ? <Spinner size="sm" /> : 'Create'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
