import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import { Layout } from './components/Layout';
import { AuthProvider, useAuth } from './context/AuthContext';
import { CertificatesPage } from './pages/CertificatesPage';
import { DashboardPage } from './pages/DashboardPage';
import { GroupsPage } from './pages/GroupsPage';
import { IdentitiesPage } from './pages/IdentitiesPage';
import { ImagesPage } from './pages/ImagesPage';
import { InstanceDetailPage } from './pages/InstanceDetailPage';
import { InstancesPage } from './pages/InstancesPage';
import { LoginPage } from './pages/LoginPage';
import { NetworksPage } from './pages/NetworksPage';
import { OperationsPage } from './pages/OperationsPage';
import { RemotesPage } from './pages/RemotesPage';

function AppRoutes() {
  const { isAuthenticated, isAuthLoading } = useAuth()

  if (isAuthLoading) {
    return (
      <div className="d-flex align-items-center justify-content-center" style={{ minHeight: '100vh' }}>
        <div className="spinner-border text-primary" />
      </div>
    )
  }

  if (!isAuthenticated) {
    return <LoginPage />
  }

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="instances" element={<InstancesPage />} />
        <Route path="instances/:name" element={<InstanceDetailPage />} />
        <Route path="images" element={<ImagesPage />} />
        <Route path="remotes" element={<RemotesPage />} />
        <Route path="networks" element={<NetworksPage />} />
        <Route path="operations" element={<OperationsPage />} />
        <Route path="auth/groups" element={<GroupsPage />} />
        <Route path="auth/identities" element={<IdentitiesPage />} />
        <Route path="certificates" element={<CertificatesPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
    </Routes>
  )
}

export default function App() {
  return (
    <HashRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </HashRouter>
  )
}
