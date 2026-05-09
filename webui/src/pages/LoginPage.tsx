import { type FormEvent, useEffect, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import type { GeneratedCertificate } from '../utils/certgen';

// ─── Password form ───────────────────────────────────────────────────────────

function PasswordForm() {
  const { login } = useAuth()
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      await login(password)
    } catch {
      setError('Invalid password. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className="mb-3">
        <label htmlFor="login-password" className="form-label">
          Password
        </label>
        <input
          id="login-password"
          type="password"
          className="form-control"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoFocus
          required
        />
      </div>
      {error && <div className="alert alert-danger py-2">{error}</div>}
      <button type="submit" className="btn btn-primary w-100" disabled={loading}>
        {loading ? (
          <>
            <span className="spinner-border spinner-border-sm me-2" />
            Signing in…
          </>
        ) : (
          'Sign in'
        )}
      </button>
    </form>
  )
}

// ─── Certificate wizard ──────────────────────────────────────────────────────

type WizardStep = 'form' | 'generating' | 'done'

function CertificateWizard() {
  const [step, setStep] = useState<WizardStep>('form')
  const [name, setName] = useState('')
  const [result, setResult] = useState<GeneratedCertificate | null>(null)
  const [copied, setCopied] = useState(false)
  const objectUrlRef = useRef<string | null>(null)

  // Clean up object URL on unmount
  useEffect(() => {
    return () => {
      if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
    }
  }, [])

  const generate = async (e: FormEvent) => {
    e.preventDefault()
    setStep('generating')
    // Dynamic import so node-forge is code-split away from the main bundle
    const { generateClientCertificateAsync } = await import('../utils/certgen')
    const cert = await generateClientCertificateAsync(name || 'caker-client')
    // Revoke previous URL
    if (objectUrlRef.current) URL.revokeObjectURL(objectUrlRef.current)
    objectUrlRef.current = URL.createObjectURL(cert.p12Blob)
    setResult(cert)
    setStep('done')
  }

  const copyPem = () => {
    if (!result) return
    navigator.clipboard.writeText(result.certPem).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }

  if (step === 'form') {
    return (
      <form onSubmit={generate}>
        <p className="text-muted small mb-3">
          Generate a self-signed client certificate to authenticate via mTLS. After importing the
          certificate into your browser or OS, add the public certificate to Caker (via the{' '}
          <strong>Certificates</strong> page or <code>cakectl</code>).
        </p>
        <div className="mb-3">
          <label htmlFor="cert-name" className="form-label">
            Certificate name
          </label>
          <input
            id="cert-name"
            type="text"
            className="form-control"
            placeholder="e.g. my-laptop"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
          <div className="form-text">Used as the certificate's Common Name.</div>
        </div>
        <button type="submit" className="btn btn-outline-primary w-100">
          <i className="bi bi-shield-lock me-2" />
          Generate certificate
        </button>
      </form>
    )
  }

  if (step === 'generating') {
    return (
      <div className="text-center py-4 text-muted">
        <div className="spinner-border text-primary mb-3" />
        <div>Generating RSA-2048 key pair…</div>
        <div className="small">This may take a few seconds.</div>
      </div>
    )
  }

  // step === 'done'
  return (
    <div>
      <div className="alert alert-success d-flex align-items-start gap-2 py-2 mb-4">
        <i className="bi bi-check-circle-fill mt-1" />
        <div>
          Certificate <strong>{result!.p12Filename}</strong> generated successfully.
        </div>
      </div>

      {/* Step 1 — Download .p12 */}
      <div className="card mb-3 border-0 bg-light">
        <div className="card-body">
          <h6 className="card-title mb-1">
            <span className="badge bg-primary rounded-circle me-2">1</span>
            Download &amp; import the certificate
          </h6>
          <p className="small text-muted mb-3">
            Import the <code>.p12</code> file into your browser or OS keychain (no passphrase).
            macOS: double-click the file. Firefox: Settings → Privacy → Certificates → Import.
          </p>
          <a
            href={objectUrlRef.current!}
            download={result!.p12Filename}
            className="btn btn-primary"
          >
            <i className="bi bi-download me-2" />
            Download {result!.p12Filename}
          </a>
        </div>
      </div>

      {/* Step 2 — Add cert to caked */}
      <div className="card mb-3 border-0 bg-light">
        <div className="card-body">
          <h6 className="card-title mb-1">
            <span className="badge bg-primary rounded-circle me-2">2</span>
            Add the certificate to Caker
          </h6>
          <p className="small text-muted mb-2">
            Copy the PEM below and add it via <strong>Security → Certificates</strong> (log in with
            your password first), or run:
          </p>
          <pre className="text-bg-dark rounded p-2 small" style={{ overflowX: 'auto', fontSize: '0.72rem' }}>
            {`cakectl certificate add --name "${result!.p12Filename.replace('.p12', '')}" <(pbpaste)`}
          </pre>
          <textarea
            readOnly
            className="form-control form-control-sm font-monospace mb-2"
            rows={6}
            value={result!.certPem}
            style={{ fontSize: '0.72rem' }}
          />
          <div className="d-flex align-items-center gap-3">
            <button onClick={copyPem} className="btn btn-sm btn-outline-secondary">
              <i className={`bi bi-${copied ? 'check2' : 'clipboard'} me-1`} />
              {copied ? 'Copied!' : 'Copy PEM'}
            </button>
            <span className="small text-muted font-monospace" style={{ fontSize: '0.7rem' }}>
              SHA-256: {result!.fingerprint}
            </span>
          </div>
        </div>
      </div>

      {/* Step 3 — Reload */}
      <div className="card border-0 bg-light">
        <div className="card-body">
          <h6 className="card-title mb-1">
            <span className="badge bg-primary rounded-circle me-2">3</span>
            Reload and connect
          </h6>
          <p className="small text-muted mb-3">
            Once the certificate is trusted by Caker, restart your browser or open a new private
            window. The browser will offer the certificate automatically.
          </p>
          <button
            onClick={() => setStep('form')}
            className="btn btn-sm btn-outline-secondary me-2"
          >
            Generate another
          </button>
          <button onClick={() => window.location.reload()} className="btn btn-sm btn-outline-primary">
            <i className="bi bi-arrow-clockwise me-1" />
            Reload page
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── LoginPage ───────────────────────────────────────────────────────────────

export function LoginPage() {
  const { authMethods } = useAuth()
  const hasPassword = authMethods.includes('basic') || authMethods.includes('bearer')
  const [tab, setTab] = useState<'password' | 'certificate'>(hasPassword ? 'password' : 'certificate')

  // Sync tab default if authMethods arrive asynchronously
  useEffect(() => {
    if (!hasPassword && tab === 'password') setTab('certificate')
  }, [hasPassword, tab])

  return (
    <div
      className="d-flex align-items-center justify-content-center"
      style={{ minHeight: '100vh', background: '#f0f2f5' }}
    >
      <div style={{ width: '100%', maxWidth: 480 }}>
        {/* Brand */}
        <div className="text-center mb-4">
          <i className="bi bi-box-fill text-primary" style={{ fontSize: '2.5rem' }} />
          <h4 className="fw-bold mt-2 mb-0">Caker</h4>
          <p className="text-muted small">Sign in to continue</p>
        </div>

        <div className="card shadow-sm">
          {/* Tabs — only shown when both methods are available */}
          {hasPassword && (
            <div className="card-header p-0">
              <ul className="nav nav-tabs border-0">
                <li className="nav-item">
                  <button
                    className={`nav-link rounded-0 ${tab === 'password' ? 'active' : ''}`}
                    onClick={() => setTab('password')}
                  >
                    <i className="bi bi-key me-2" />
                    Password
                  </button>
                </li>
                <li className="nav-item">
                  <button
                    className={`nav-link rounded-0 ${tab === 'certificate' ? 'active' : ''}`}
                    onClick={() => setTab('certificate')}
                  >
                    <i className="bi bi-shield-lock me-2" />
                    Certificate
                  </button>
                </li>
              </ul>
            </div>
          )}

          <div className="card-body p-4">
            {tab === 'password' && <PasswordForm />}
            {tab === 'certificate' && <CertificateWizard />}
          </div>
        </div>
      </div>
    </div>
  )
}
