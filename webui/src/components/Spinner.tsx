export function Spinner({ size = 'md' }: { size?: 'sm' | 'md' }) {
  const cls =
    size === 'sm' ? 'spinner-border spinner-border-sm' : 'spinner-border'
  return (
    <div className={cls} role="status">
      <span className="visually-hidden">Loading…</span>
    </div>
  )
}

export function PageSpinner() {
  return (
    <div className="d-flex justify-content-center align-items-center py-5">
      <Spinner />
    </div>
  )
}
