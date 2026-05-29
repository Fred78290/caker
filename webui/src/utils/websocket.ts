/**
 * Build a WebSocket URL for a given path, adapting the protocol (ws/wss)
 * from the current page protocol, so it works in both dev (Vite proxy) and
 * production (same origin as caked).
 */
export function wsBaseUrl(): string {
  const loc = window.location
  const proto = loc.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${proto}//${loc.host}`
}

/**
 * WebSocket URL for a pending LXD operation WebSocket fd.
 * Path: /1.0/operations/{operationId}/websocket?secret={secret}
 */
export function operationWsUrl(operationId: string, secret: string): string {
  return `${wsBaseUrl()}/1.0/operations/${operationId}/websocket?secret=${encodeURIComponent(secret)}`
}
