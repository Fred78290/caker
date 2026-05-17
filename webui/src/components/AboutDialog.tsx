import { useEffect, useRef, useState } from 'react';
import { getServerInfo } from '../api/server';

interface Props {
  id: string
}

export function AboutDialog({ id }: Props) {
  const closeRef = useRef<HTMLButtonElement>(null)
  const [version, setVersion] = useState<string | null>(null)

  useEffect(() => {
    getServerInfo()
      .then((response) => {
        const serverVersion = response.data.metadata?.environment.server_version
        setVersion(serverVersion || 'Unknown')
      })
      .catch(() => {
        setVersion('Unknown')
      })
  }, [])

  return (
    <div className="modal fade" id={id} tabIndex={-1} aria-hidden="true">
      <div className="modal-dialog modal-dialog-centered">
        <div className="modal-content">
          <div className="modal-header border-0">
            <div className="d-flex align-items-center gap-2">
              <i className="bi bi-box-fill text-primary fs-5" />
              <h5 className="modal-title">About Caker</h5>
            </div>
            <button
              ref={closeRef}
              type="button"
              className="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
            />
          </div>
          <div className="modal-body">
            <p className="mb-3">
              <strong>Caker</strong> is a modern web-based LXD container management interface.
            </p>
            <p className="mb-3">
              Manage instances, images, networks, and more with an intuitive, responsive UI.
            </p>
            <div className="bg-light p-3 rounded mb-3">
              <small className="text-muted d-block mb-1"><strong>Version:</strong> {version || 'Loading...'}</small>
              <small className="text-muted d-block"><strong>Built with:</strong> React + TypeScript + Bootstrap</small>
            </div>
            <div className="mb-3">
              <p className="mb-2">
                <strong>Resources:</strong>
              </p>
              <ul className="list-unstyled small">
                <li className="mb-1">
                  <i className="bi bi-book me-2 text-muted" />
                  <a href="https://caker.aldunelabs.com" target="_blank" rel="noopener noreferrer" className="link-primary">Documentation</a>
                </li>
                <li>
                  <i className="bi bi-github me-2 text-muted" />
                  <a href="https://github.com/Fred78290/caker" target="_blank" rel="noopener noreferrer" className="link-primary">GitHub Repository</a>
                </li>
              </ul>
            </div>
            <div className="alert alert-info alert-sm mb-0" style={{ fontSize: '0.85rem' }}>
              <i className="bi bi-info-circle me-2" />
              Found a bug or have a feature request? Please <a href="https://github.com/Fred78290/caker/issues" target="_blank" rel="noopener noreferrer" className="alert-link">open an issue</a> on GitHub.
            </div>
          </div>
          <div className="modal-footer border-0">
            <button
              type="button"
              className="btn btn-primary"
              data-bs-dismiss="modal"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
