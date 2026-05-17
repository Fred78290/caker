import { useCallback, useEffect, useState } from 'react';
import { deleteImage, listImages, listRemoteImages, pullImage } from '../api/images';
import { listRemotes } from '../api/remotes';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import type { LXDImage, LXDRemote } from '../types/lxd';
import { CreateInstanceModal } from './CreateInstanceModal';

function formatSize(bytes: number) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${units[i]}`
}

function detectImageRemote(img: LXDImage): string {
  const remotes = img.aliases
    .map((a) => {
      const sep = a.name.indexOf('://')
      return sep > 0 ? a.name.slice(0, sep) : ''
    })
    .filter((v) => v.length > 0)

  if (remotes.length === 0) return '—'
  const unique = Array.from(new Set(remotes))
  return unique.join(', ')
}

export function ImagesPage() {
  const [mode, setMode] = useState<'cache' | 'remote'>('cache')
  const [images, setImages] = useState<LXDImage[]>([])
  const [filter, setFilter] = useState('')
  const [remotes, setRemotes] = useState<LXDRemote[]>([])
  const [selectedRemote, setSelectedRemote] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [pullingFingerprint, setPullingFingerprint] = useState<string | null>(null)
  const [deletingFingerprint, setDeletingFingerprint] = useState<string | null>(null)
  const [createInstanceAlias, setCreateInstanceAlias] = useState<string>('')

  const refresh = useCallback(() => {
    setLoading(true)
    if (mode === 'remote') {
      if (!selectedRemote) {
        setImages([])
        setLoading(false)
        return
      }

      listRemoteImages(selectedRemote)
        .then((r) => setImages(r.data.metadata ?? []))
        .catch((e) => setError(String(e)))
        .finally(() => setLoading(false))
      return
    }

    listImages()
      .then((r) => setImages(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [mode, selectedRemote])

  const loadRemotes = useCallback(() => {
    listRemotes()
      .then((r) => {
        const data = r.data.metadata ?? []
        setRemotes(data)

        if (selectedRemote) {
          const stillExists = data.some((item) => item.name === selectedRemote)
          if (!stillExists) {
            setSelectedRemote(data[0]?.name ?? '')
          }
        } else if (data.length > 0) {
          setSelectedRemote(data[0].name)
        }
      })
      .catch((e) => setError(String(e)))
  }, [selectedRemote])

  useEffect(() => { loadRemotes() }, [loadRemotes])
  useEffect(() => { refresh() }, [refresh])

  const filteredImages = images.filter((img) => {
    const q = filter.trim().toLowerCase()
    if (!q) return true

    const inAlias = img.aliases.some((a) => a.name.toLowerCase().includes(q))
    return (
      img.fingerprint.toLowerCase().includes(q)
      || img.architecture.toLowerCase().includes(q)
      || img.type.toLowerCase().includes(q)
      || inAlias
    )
  })

  const displayedImages = [...filteredImages].sort((a, b) => {
    const aliasA = a.aliases[0]?.name ?? ''
    const aliasB = b.aliases[0]?.name ?? ''
    const byAlias = aliasA.localeCompare(aliasB)
    if (byAlias !== 0) return byAlias

    return a.fingerprint.localeCompare(b.fingerprint)
  })

  const pullSelectedImage = async (img: LXDImage) => {
    if (!selectedRemote) {
      setError('Please select a remote before pulling an image')
      return
    }

    const preferredAlias = img.aliases[0]?.name
    if (!preferredAlias) {
      setError('This image has no alias and cannot be pulled from the Web UI yet')
      return
    }

    setPullingFingerprint(img.fingerprint)
    try {
      await pullImage({ remote: selectedRemote, alias: preferredAlias })
      setMode('cache')
      await refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setPullingFingerprint(null)
    }
  }

  const createInstanceFromImage = (img: LXDImage) => {
    if (!selectedRemote) {
      setError('Please select a remote before creating an instance')
      return
    }

    const firstAlias = img.aliases[0]?.name
    const imageRef = firstAlias
      ? (firstAlias.includes('://')
          ? firstAlias.split('://').slice(1).join('://')
          : firstAlias)
      : img.fingerprint

    setCreateInstanceAlias(`${selectedRemote}:${imageRef}`)
    setError(null)
  }

  const deleteCachedImage = async (img: LXDImage) => {
    if (!window.confirm(`Delete cached image "${img.aliases[0]?.name ?? img.fingerprint}"?`)) {
      return
    }

    let toDelete: string
    
    if (img.fingerprint && img.fingerprint.length > 0) {
      toDelete = img.fingerprint
    } else if (img.aliases[0]?.name && img.aliases[0].name.length > 0) {
      toDelete = img.aliases[0].name
    } else {
      setError('Image has no fingerprint or alias to identify it for deletion')
      return
    }

    setDeletingFingerprint(toDelete)
    setError(null)
    try {
      await deleteImage(toDelete)
      await refresh()
    } catch (e) {
      setError(String(e))
    } finally {
      setDeletingFingerprint(null)
    }
  }

  if (loading) return <PageSpinner />

  const subtitle = mode === 'remote'
    ? `${filteredImages.length}/${images.length} remote image${images.length !== 1 ? 's' : ''}${selectedRemote ? ` from ${selectedRemote}` : ''}`
    : `${filteredImages.length}/${images.length} cached image${images.length !== 1 ? 's' : ''}`

  return (
    <>
      <PageHeader
        title="Images"
        subtitle={subtitle}
        actions={
          <>
            <button className="btn btn-outline-secondary btn-sm" onClick={loadRemotes}>
              <i className="bi bi-cloud-arrow-down me-1" />
              Reload Remotes
            </button>
            <button className="btn btn-outline-secondary btn-sm" onClick={refresh}>
              <i className="bi bi-arrow-clockwise me-1" />
              Refresh
            </button>
          </>
        }
      />

      <div className="card border-0 shadow-sm mb-3">
        <div className="card-body d-flex flex-wrap gap-3 align-items-center">
          <div className="btn-group btn-group-sm" role="group" aria-label="Image source">
            <button
              type="button"
              className={`btn ${mode === 'cache' ? 'btn-primary' : 'btn-outline-primary'}`}
              onClick={() => setMode('cache')}
            >
              <i className="bi bi-database me-1" />
              Local Cache
            </button>
            <button
              type="button"
              className={`btn ${mode === 'remote' ? 'btn-primary' : 'btn-outline-primary'}`}
              onClick={() => setMode('remote')}
            >
              <i className="bi bi-globe me-1" />
              Remote Browser
            </button>
          </div>

          <div className="d-flex align-items-center gap-2">
            <label className="form-label mb-0 small text-muted">Remote</label>
            <select
              className="form-select form-select-sm"
              style={{ minWidth: 240 }}
              value={selectedRemote}
              onChange={(e) => setSelectedRemote(e.target.value)}
              disabled={mode !== 'remote'}
            >
              {remotes.length === 0 && <option value="">No remotes</option>}
              {remotes.map((remote) => (
                <option key={remote.name} value={remote.name}>{remote.name} - {remote.url}</option>
              ))}
            </select>
          </div>

          <div className="d-flex align-items-center gap-2 ms-auto">
            <label className="form-label mb-0 small text-muted">Filter</label>
            <input
              className="form-control form-control-sm"
              style={{ minWidth: 260 }}
              placeholder="Alias, fingerprint, architecture..."
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
            />
          </div>
        </div>
      </div>

      {error && (
        <div className="alert alert-danger alert-dismissible">
          {error}
          <button className="btn-close" onClick={() => setError(null)} />
        </div>
      )}

      <div className="card border-0 shadow-sm">
        {mode === 'cache' && (
          <div className="card-header bg-white border-bottom-0 pb-0">
            <small className="text-muted">
              <i className="bi bi-sort-alpha-down me-1" />
              Sorted by: Remote, Alias
            </small>
          </div>
        )}
        <div className="table-responsive">
          <table className="table table-hover mb-0 align-middle">
            <thead className="table-light">
              <tr>
                <th>Aliases</th>
                <th>Fingerprint</th>
                <th>Type</th>
                {mode === 'cache' && <th>Remote</th>}
                <th>Size</th>
                <th>Architecture</th>
                <th>Cached</th>
                <th>Uploaded</th>
                {mode === 'cache' && <th className="text-end">Action</th>}
                {mode === 'remote' && <th className="text-end">Action</th>}
              </tr>
            </thead>
            <tbody>
              {displayedImages.length === 0 && (
                <tr>
                  <td colSpan={mode === 'remote' ? 8 : 9} className="text-center text-muted py-4">
                    {mode === 'remote' ? 'No images found on selected remote' : 'No cached images found'}
                  </td>
                </tr>
              )}
              {displayedImages.map((img) => (
                <tr key={img.fingerprint}>
                  <td>
                    {img.aliases.map((a) => (
                      <span key={a.name} className="badge bg-primary me-1">
                        {a.name}
                      </span>
                    ))}
                  </td>
                  <td>
                    <code className="small">{img.fingerprint.slice(0, 12)}</code>
                  </td>
                  <td>
                    <span className="badge bg-light text-dark border">
                      {img.type}
                    </span>
                  </td>
                  {mode === 'cache' && (
                    <td>
                      <small className="text-muted">{detectImageRemote(img)}</small>
                    </td>
                  )}
                  <td>{formatSize(img.size)}</td>
                  <td>
                    <small className="text-muted">{img.architecture}</small>
                  </td>
                  <td>
                    {img.cached ? (
                      <i className="bi bi-check-circle text-success" />
                    ) : (
                      <i className="bi bi-dash text-muted" />
                    )}
                  </td>
                  <td>
                    <small className="text-muted">
                      {img.uploaded_at
                        ? new Date(img.uploaded_at).toLocaleDateString()
                        : '—'}
                    </small>
                  </td>
                  {mode === 'cache' && (
                    <td className="text-end">
                      <button
                        className="btn btn-outline-danger btn-sm"
                        disabled={deletingFingerprint !== null}
                        onClick={() => deleteCachedImage(img)}
                      >
                        {deletingFingerprint === img.fingerprint ? (
                          <span className="spinner-border spinner-border-sm" role="status" aria-hidden="true" />
                        ) : (
                          <>
                            <i className="bi bi-trash me-1" />
                          </>
                        )}
                      </button>
                    </td>
                  )}
                  {mode === 'remote' && (
                    <td className="text-end">
                      <div className="btn-group btn-group-sm">
                        <button
                          className="btn btn-outline-primary"
                          disabled={pullingFingerprint !== null}
                          onClick={() => pullSelectedImage(img)}
                        >
                          {pullingFingerprint === img.fingerprint ? (
                            <span className="spinner-border spinner-border-sm" role="status" aria-hidden="true" />
                          ) : (
                            <>
                              <i className="bi bi-download me-1" />Pull
                            </>
                          )}
                        </button>
                        <button
                          className="btn btn-outline-success"
                          data-bs-toggle="modal"
                          data-bs-target="#createInstanceModal"
                          disabled={pullingFingerprint !== null}
                          onClick={() => createInstanceFromImage(img)}
                        >
                          <i className="bi bi-plus-square me-1" />Create
                        </button>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <CreateInstanceModal
        initialAlias={createInstanceAlias}
        onCreated={() => {
          setMode('cache')
          setTimeout(refresh, 1500)
        }}
      />
    </>
  )
}
