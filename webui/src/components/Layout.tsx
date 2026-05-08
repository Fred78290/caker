import { NavLink, Outlet } from 'react-router-dom';

interface NavItemProps {
  to: string
  icon: string
  label: string
}

function NavItem({ to, icon, label }: NavItemProps) {
  return (
    <NavLink
      to={to}
      className={({ isActive }) =>
        'nav-link mb-1 rounded px-3 py-2 d-flex align-items-center gap-2 ' +
        (isActive ? 'bg-primary text-white' : 'text-white-50 link-light')
      }
      style={{ fontSize: '0.9rem' }}
    >
      <i className={`bi bi-${icon}`} style={{ fontSize: '1rem' }} />
      {label}
    </NavLink>
  )
}

function NavSection({ label }: { label: string }) {
  return (
    <div
      className="text-uppercase text-secondary mt-3 mb-1 px-3"
      style={{ fontSize: '0.7rem', letterSpacing: '0.08em' }}
    >
      {label}
    </div>
  )
}

export function Layout() {
  return (
    <div className="d-flex" style={{ minHeight: '100vh' }}>
      {/* ── Sidebar ─────────────────────────────────────────── */}
      <nav
        className="d-flex flex-column py-3 px-2 text-white flex-shrink-0"
        style={{ width: 220, background: '#1e2030' }}
      >
        {/* Brand */}
        <NavLink
          to="/dashboard"
          className="d-flex align-items-center gap-2 mb-3 px-3 text-decoration-none"
        >
          <i className="bi bi-box-fill text-primary fs-5" />
          <span className="fs-5 fw-bold text-white">Caker</span>
        </NavLink>

        <NavItem to="/dashboard" icon="speedometer2" label="Dashboard" />

        <NavSection label="Compute" />
        <NavItem to="/instances" icon="hdd-stack" label="Instances" />
        <NavItem to="/images" icon="layers" label="Images" />
        <NavItem to="/networks" icon="diagram-3" label="Networks" />

        <NavSection label="Monitor" />
        <NavItem to="/operations" icon="clock-history" label="Operations" />

        <NavSection label="Security" />
        <NavItem to="/auth/groups" icon="people-fill" label="Groups" />
        <NavItem to="/auth/identities" icon="person-badge" label="Identities" />
        <NavItem to="/certificates" icon="shield-lock" label="Certificates" />
      </nav>

      {/* ── Main content ────────────────────────────────────── */}
      <main className="flex-grow-1 bg-light overflow-auto">
        <div className="p-4">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
