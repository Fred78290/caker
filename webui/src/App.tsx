import { HashRouter, Navigate, Route, Routes } from 'react-router-dom';
import { Layout } from './components/Layout';
import { CertificatesPage } from './pages/CertificatesPage';
import { DashboardPage } from './pages/DashboardPage';
import { GroupsPage } from './pages/GroupsPage';
import { IdentitiesPage } from './pages/IdentitiesPage';
import { ImagesPage } from './pages/ImagesPage';
import { InstancesPage } from './pages/InstancesPage';
import { NetworksPage } from './pages/NetworksPage';
import { OperationsPage } from './pages/OperationsPage';

export default function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="instances" element={<InstancesPage />} />
          <Route path="images" element={<ImagesPage />} />
          <Route path="networks" element={<NetworksPage />} />
          <Route path="operations" element={<OperationsPage />} />
          <Route path="auth/groups" element={<GroupsPage />} />
          <Route path="auth/identities" element={<IdentitiesPage />} />
          <Route path="certificates" element={<CertificatesPage />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </HashRouter>
  )
}
