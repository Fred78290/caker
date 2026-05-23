import { forwardRef, useCallback, useImperativeHandle, useLayoutEffect, useRef, useState } from 'react';
import { VncScreen, VncScreenHandle } from 'react-vnc';
import { operationWsUrl } from '../utils/websocket';

interface Props {
  operationId: string
  fds: Record<string, string>
  onDisconnected?: () => void
  onConnected?: () => void
}

export interface VGAConsoleHandle {
  toggleFullScreen: () => void
}

export const VGAConsole = forwardRef<VGAConsoleHandle, Props>(
  function VGAConsole({ operationId, fds, onDisconnected, onConnected }, ref) {
    const containerRef = useRef<HTMLDivElement>(null)
    const vncRef = useRef<VncScreenHandle>(null)
    const [status, setStatus] = useState<'connecting' | 'connected' | 'error'>('connecting')
    const [errorMsg, setErrorMsg] = useState('')
    const isIntentionalDisconnect = useRef(false)

    const url = operationWsUrl(operationId, fds['0'])
    const vncPassword: string = fds['vnc-password'] ?? ''
    const vncCredentials = vncPassword
      ? { username: '', password: vncPassword, target: '' }
      : undefined

    // useLayoutEffect cleanups are synchronous and fire before any useEffect
    // cleanup in the subtree, so the flag is set before VncScreen's disconnect.
    useLayoutEffect(() => {
      isIntentionalDisconnect.current = false
      return () => {
        isIntentionalDisconnect.current = true
      }
    }, [url])

    const toggleFullScreen = useCallback(() => {
      const el = containerRef.current
      if (el) {
        if (!document.fullscreenElement) {
          el.requestFullscreen().catch(console.error)
        } else if (document.exitFullscreen) {
          document.exitFullscreen().catch(console.error)
        }
      }
    }, [])

    useImperativeHandle(ref, () => ({ toggleFullScreen }), [toggleFullScreen])

    return (
      <div ref={containerRef} style={{ position: 'relative', width: '100%', height: '100%', background: '#000' }}>
        {/* Status overlay */}
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
        {/* key=url forces a full remount when the session changes */}
        <VncScreen
          key={url}
          ref={vncRef}
          url={url}
          rfbOptions={vncCredentials ? { credentials: vncCredentials } : undefined}
          scaleViewport={false}
          resizeSession
          viewOnly={false}
          focusOnClick
          showDotCursor={false}
          style={{ width: '100%', height: '100%' }}
          onConnect={() => {
            setStatus('connected')
            onConnected?.()
            window.setTimeout(() => vncRef.current?.focus(), 0)
          }}
          onDisconnect={() => {
            if (isIntentionalDisconnect.current) return
            setStatus('error')
            setErrorMsg('VNC connection lost')
            onDisconnected?.()
          }}
          onCredentialsRequired={() => {
            if (vncCredentials) {
              vncRef.current?.sendCredentials(vncCredentials)
            } else {
              setStatus('error')
              setErrorMsg('VNC server requires a password but none was provided')
              onDisconnected?.()
              isIntentionalDisconnect.current = true
              vncRef.current?.disconnect()
            }
          }}
        />
      </div>
    )
  }
)
