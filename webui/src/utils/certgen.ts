import forge from 'node-forge';

export interface GeneratedCertificate {
  /** PEM-encoded public certificate — share this with caked (/1.0/certificates). */
  certPem: string
  /** SHA-256 fingerprint of the DER certificate (colon-separated uppercase hex). */
  fingerprint: string
  /** PKCS#12 blob ready for browser/OS import. */
  p12Blob: Blob
  /** Suggested filename for the .p12 download. */
  p12Filename: string
}

/**
 * Generate a self-signed client certificate using node-forge.
 * This is synchronous and blocks for ~1-3 s on RSA-2048.
 * Wrap in a setTimeout before calling so the spinner can render.
 */
function generateClientCertificate(commonName: string): GeneratedCertificate {
  const keys = forge.pki.rsa.generateKeyPair(2048)
  const cert = forge.pki.createCertificate()

  cert.publicKey = keys.publicKey
  cert.serialNumber = forge.util.bytesToHex(forge.random.getBytesSync(8))

  const now = new Date()
  const expiry = new Date(now)
  expiry.setFullYear(now.getFullYear() + 10)
  cert.validity.notBefore = now
  cert.validity.notAfter = expiry

  const attrs = [{ name: 'commonName', value: commonName }]
  cert.setSubject(attrs)
  cert.setIssuer(attrs)

  cert.setExtensions([
    { name: 'basicConstraints', cA: false },
    { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
    { name: 'extKeyUsage', clientAuth: true },
  ])

  cert.sign(keys.privateKey, forge.md.sha256.create())

  const certPem = forge.pki.certificateToPem(cert)

  // SHA-256 fingerprint of the DER-encoded certificate
  const certDer = forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes()
  const md = forge.md.sha256.create()
  md.update(certDer)
  const fingerprint = md.digest().toHex().match(/.{2}/g)!.join(':').toUpperCase()

  // PKCS#12 — no passphrase, 3DES encryption for broad OS compatibility
  const p12Asn1 = forge.pkcs12.toPkcs12Asn1(keys.privateKey, [cert], '', {
    algorithm: '3des',
    friendlyName: commonName,
  })
  const p12Raw = forge.asn1.toDer(p12Asn1).getBytes()
  const p12Uint8 = new Uint8Array(p12Raw.length)
  for (let i = 0; i < p12Raw.length; i++) p12Uint8[i] = p12Raw.charCodeAt(i)
  const p12Blob = new Blob([p12Uint8], { type: 'application/x-pkcs12' })

  return {
    certPem,
    fingerprint,
    p12Blob,
    p12Filename: `${commonName.replace(/[^a-zA-Z0-9_-]/g, '_')}.p12`,
  }
}

/**
 * Async wrapper — defers the blocking RSA generation by one tick so the UI
 * can render a loading spinner before the thread is blocked.
 */
export function generateClientCertificateAsync(commonName: string): Promise<GeneratedCertificate> {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      try {
        resolve(generateClientCertificate(commonName))
      } catch (e) {
        reject(e)
      }
    }, 50)
  })
}
