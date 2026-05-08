import { useCallback, useEffect, useState } from 'react';
import { deleteCertificate, listCertificates } from '../api/auth';
import { ConfirmDialog, openModal } from '../components/ConfirmDialog';
import { PageHeader } from '../components/PageHeader';
import { PageSpinner } from '../components/Spinner';
import type { LXDCertificate } from '../types/lxd';

export function CertificatesPage() {
  const [certs, setCerts] = useState<LXDCertificate[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selected, setSelected] = useState<LXDCertificate | null>(null)

  const refresh = useCallback(() => {
    setLoading(true)
    listCertificates()
      .then((r) => setCerts(r.data.metadata ?? []))
      .catch((e) => setError(String(e)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { refresh() }, [refresh])

  const doDelete = async () => {
    if (!selected) return
    try {
      await deleteCertificate(selected.fingerprint)
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
        title="Certificates"
        subtitle={`${certs.length} certificate${certs.length !== 1 ? 's' : ''}`}
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
                <th>Fingerprint</th>
                <th>Type</th>
                <th>Restricted</th>
                <th>Projects</th>
                <th className="text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {certs.length === 0 && (
                <tr>
                  <td colSpan={6} className="text-center text-muted py-4">
                    No certificates found
                  </td>
                </tr>
              )}
              {certs.map((cert) => (
                <tr key={cert.fingerprint}>
                  <td className="fw-medium">{cert.name || '—'}</td>
                  <td>
                    <code className="small">{cert.fingerprint.slice(0, 16)}</code>
                  </td>
                  <td>
                    <span className="badge bg-light text-dark border">
                      {cert.type}
                    </span>
                  </td>
                  <td>
                    {cert.restricted ? (
                      <i className="bi bi-lock-fill text-warning" />
                    ) : (
                      <i className="bi bi-unlock text-muted" />
                    )}
                  </td>
                  <td>
                    <small className="text-muted">
                      {(cert.projects ?? []).join(', ') || 'all'}
                    </small>
                  </td>
                  <td className="text-end">
                    <button
                      className="btn btn-sm btn-outline-danger"
                      onClick={() => {
                        setSelected(cert)
                        openModal('confirmDeleteCert')
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
        id="confirmDeleteCert"
        title="Delete Certificate"
        message={`Are you sure you want to delete certificate "${selected?.name || selected?.fingerprint.slice(0, 16)}"?`}
        onConfirm={doDelete}
      />
    </>
  )
}
