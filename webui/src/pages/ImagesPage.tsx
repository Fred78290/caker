import { useCallback, useEffect, useState } from 'react';
import { listImages } from '../api/images';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import type { LXDImage } from '../types/lxd';

function formatSize(bytes: number) {
  if (bytes === 0) return '0 B'
  const k = 1024
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${units[i]}`
}

export function ImagesPage() {
  const [images, setImages] = useState<LXDImage[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(() => {
    setLoading(true)
    listImages()
      .then((r) => setImages(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  if (loading) return <PageSpinner />

  return (
    <>
      <PageHeader
        title="Images"
        subtitle={`${images.length} image${images.length !== 1 ? 's' : ''}`}
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
                <th>Fingerprint</th>
                <th>Type</th>
                <th>Aliases</th>
                <th>Size</th>
                <th>Architecture</th>
                <th>Cached</th>
                <th>Uploaded</th>
              </tr>
            </thead>
            <tbody>
              {images.length === 0 && (
                <tr>
                  <td colSpan={7} className="text-center text-muted py-4">
                    No images found
                  </td>
                </tr>
              )}
              {images.map((img) => (
                <tr key={img.fingerprint}>
                  <td>
                    <code className="small">{img.fingerprint.slice(0, 12)}</code>
                  </td>
                  <td>
                    <span className="badge bg-light text-dark border">
                      {img.type}
                    </span>
                  </td>
                  <td>
                    {img.aliases.map((a) => (
                      <span key={a.name} className="badge bg-primary me-1">
                        {a.name}
                      </span>
                    ))}
                  </td>
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
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
