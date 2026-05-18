import { FitAddon } from '@xterm/addon-fit';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { useEffect, useRef } from 'react';
import { operationWsUrl } from '../utils/websocket';

interface Props {
  operationId: string
  /** fd name → WebSocket secret map returned by exec/console. */
  fds: Record<string, string>
  isActive: boolean
}

/**
 * Interactive xterm.js terminal bridged to the LXD exec WebSocket.
 *
 * fd "0"       : raw PTY data (binary, bidirectional)
 * fd "control" : JSON control channel (resize/signal)
 */
export function TerminalConsole({ operationId, fds, isActive }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const fitVisibleRef = useRef<() => void>(() => {})

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    // ── xterm ────────────────────────────────────────────────────────────────
    const term = new Terminal({
      cursorBlink: true,
      scrollback: 5000,
      theme: {
        background: '#1e2030',
        foreground: '#cdd6f4',
        cursor: '#cdd6f4',
        black: '#45475a',
        red: '#f38ba8',
        green: '#a6e3a1',
        yellow: '#f9e2af',
        blue: '#89b4fa',
        magenta: '#cba6f7',
        cyan: '#89dceb',
        white: '#bac2de',
        brightBlack: '#585b70',
        brightRed: '#f38ba8',
        brightGreen: '#a6e3a1',
        brightYellow: '#f9e2af',
        brightBlue: '#89b4fa',
        brightMagenta: '#cba6f7',
        brightCyan: '#89dceb',
        brightWhite: '#a6adc8',
      },
      fontFamily: '"Cascadia Code", "JetBrains Mono", Menlo, monospace',
      fontSize: 13,
      lineHeight: 1.2,
    })
    const fitAddon = new FitAddon()
    term.loadAddon(fitAddon)
    term.open(el)

    const fitIfVisible = () => {
      // Hidden containers (display:none) report invalid dimensions, which can corrupt terminal wrapping.
      if (el.offsetParent === null || el.clientWidth <= 0 || el.clientHeight <= 0) {
        return
      }

      fitAddon.fit()

      if (term.cols > 0 && term.rows > 0) {
        sendResize(term.cols, term.rows)
      }
    }
    fitVisibleRef.current = fitIfVisible

    // ── WebSockets ───────────────────────────────────────────────────────────
    const dataWs = new WebSocket(operationWsUrl(operationId, fds['0']))
    dataWs.binaryType = 'arraybuffer'

    const controlWs = fds['control']
      ? new WebSocket(operationWsUrl(operationId, fds['control']))
      : null

    const sendResize = (cols: number, rows: number) => {
      if (controlWs?.readyState === WebSocket.OPEN) {
        controlWs.send(
          JSON.stringify({ command: 'window-resize', args: { width: cols, height: rows } }),
        )
      }
    }

    // VNC/exec data: binary bytes → write to terminal
    dataWs.onmessage = (e: MessageEvent) => {
      if (e.data instanceof ArrayBuffer) {
        term.write(new Uint8Array(e.data))
      } else if (typeof e.data === 'string') {
        term.write(e.data)
      }
    }

    dataWs.onopen = () => {
      requestAnimationFrame(() => fitIfVisible())
    }

    dataWs.onclose = () => {
      term.write('\r\n\x1b[90m[disconnected]\x1b[0m\r\n')
    }

    // Terminal input → data WebSocket
    const inputDispose = term.onData((data) => {
      if (dataWs.readyState === WebSocket.OPEN) {
        dataWs.send(data)
      }
    })

    // Resize → fit + control channel
    const resizeObs = new ResizeObserver(() => {
      fitIfVisible()
    })
    resizeObs.observe(el)

    const termResizeDispose = term.onResize(({ cols, rows }) => {
      sendResize(cols, rows)
    })

    return () => {
      resizeObs.disconnect()
      inputDispose.dispose()
      termResizeDispose.dispose()
      dataWs.close()
      controlWs?.close()
      term.dispose()
      fitVisibleRef.current = () => {}
    }
  }, [operationId, fds])

  useEffect(() => {
    if (!isActive) return

    requestAnimationFrame(() => {
      fitVisibleRef.current()
    })
  }, [isActive])

  return (
    <div
      ref={containerRef}
      style={{ width: '100%', height: '100%', minHeight: 0, background: '#1e2030' }}
    />
  )
}
