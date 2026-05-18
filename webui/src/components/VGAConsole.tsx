// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore – @novnc/novnc ships JS without bundled TS types; types are provided inline.
import RFB from '@novnc/novnc';
import { useEffect, useRef, useState } from 'react';
import { operationWsUrl } from '../utils/websocket';

interface Props {
  operationId: string
  /** fd name → WebSocket secret map returned by console API.
   *  "0"           → WebSocket secret for VNC data channel.
   *  "vnc-password" → VNC authentication password (may be empty/absent). */
  fds: Record<string, string>
  onDisconnected?: () => void
}

/**
 * VGA console using noVNC (RFB protocol over WebSocket).
 *
 * The backend proxies raw VNC/RFB bytes over the WebSocket for fd "0".
 * noVNC handles the full RFB handshake, including optional password auth.
 */
export function VGAConsole({ operationId, fds, onDisconnected }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [status, setStatus] = useState<'connecting' | 'connected' | 'error'>('connecting')
  const [errorMsg, setErrorMsg] = useState('')

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const url = operationWsUrl(operationId, fds['0'])
    const vncPassword: string = fds['vnc-password'] ?? ''
    let isIntentionalDisconnect = false

    setStatus('connecting')
    setErrorMsg('')

    let rfb: InstanceType<typeof RFB>
    try {
      rfb = new RFB(el, url, {
        ...(vncPassword ? { credentials: { password: vncPassword } } : {}),
        wsProtocols: [],
      }) as InstanceType<typeof RFB>

      // Scale the VNC framebuffer to fill the container.
      rfb.scaleViewport = true
      rfb.resizeSession = false
      rfb.viewOnly = false
      rfb.focusOnClick = true
      rfb.showDotCursor = true // Affiche un curseur local si le serveur n’envoie rien

      rfb.addEventListener('connect', () => {
        setStatus('connected')
        // Ensure keyboard is grabbed as soon as the session is connected.
        window.setTimeout(() => rfb.focus(), 0)
      })
      rfb.addEventListener('disconnect', (e: CustomEvent) => {
        if (isIntentionalDisconnect) return

        const clean: boolean = (e as CustomEvent<{ clean: boolean }>).detail?.clean ?? false
        if (!clean) {
          setStatus('error')
          setErrorMsg('VNC connection lost')
          onDisconnected?.()
        }
      })
      rfb.addEventListener('credentialsrequired', () => {
        // If the server requires credentials but we have none, show error.
        if (!vncPassword) {
          setStatus('error')
          setErrorMsg('VNC server requires a password but none was provided')
          onDisconnected?.()
          isIntentionalDisconnect = true
          rfb.disconnect()
        }
      })
    } catch (err) {
      setStatus('error')
      setErrorMsg(String(err))
      return
    }

    return () => {
      isIntentionalDisconnect = true
      rfb.disconnect()
    }
  }, [operationId, fds])

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', background: '#000' }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: status === 'connecting' || status === 'error' ? 'flex' : 'none',
          alignItems: 'center',
          justifyContent: 'center',
          background: status === 'connecting'
            ? 'rgba(0,0,0,0.7)'
            : status === 'error'
            ? 'rgba(0,0,0,0.8)'
            : 'transparent',
          color: status === 'error' ? '#f38ba8' : '#fff',
          zIndex: 10,
          flexDirection: 'column',
          gap: status === 'error' ? 8 : 12,
          padding: status === 'error' ? 24 : undefined,
          textAlign: status === 'error' ? 'center' : undefined,
          pointerEvents: 'none',
          opacity: status === 'connecting' || status === 'error' ? 1 : 0,
          transition: 'opacity 0.3s',
        }}
      >
        {status === 'connecting' && <><div className="spinner-border text-primary" /><span>Connecting to VGA console…</span></>}
        {status === 'error' && <><i className="bi bi-exclamation-triangle fs-2" /><span>{errorMsg || 'VGA console error'}</span></>}
      </div>
      {/* noVNC mounts its canvas here */}
      <div
        ref={containerRef}
        tabIndex={0}
        style={{ width: '100%', height: '100%', outline: 'none' }}
      />
    </div>
  )
}
