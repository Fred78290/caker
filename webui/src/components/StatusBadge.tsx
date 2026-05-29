const STATUS_COLOR: Record<string, string> = {
  Running: 'success',
  Stopped: 'secondary',
  Frozen: 'info',
  Starting: 'warning',
  Stopping: 'warning',
  Created: 'primary',
  Pending: 'warning',
  Success: 'success',
  Failure: 'danger',
  Error: 'danger',
  Unavailable: 'secondary',
}

export function StatusBadge({ status }: { status: string }) {
  const color = STATUS_COLOR[status] ?? 'secondary'
  return <span className={`badge bg-${color}`}>{status}</span>
}
