interface Props {
  title: string
  subtitle?: string
  actions?: React.ReactNode
}

export function PageHeader({ title, subtitle, actions }: Props) {
  return (
    <div className="d-flex align-items-center justify-content-between mb-4">
      <div>
        <h4 className="mb-0 fw-semibold">{title}</h4>
        {subtitle && <small className="text-muted">{subtitle}</small>}
      </div>
      {actions && <div className="d-flex gap-2">{actions}</div>}
    </div>
  )
}
