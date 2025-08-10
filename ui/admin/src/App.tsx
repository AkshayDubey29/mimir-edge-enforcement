
import { Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Overview } from './pages/Overview';
import { Tenants } from './pages/Tenants';
import { Denials } from './pages/Denials';
import { Health } from './pages/Health';
import { Pipeline } from './pages/Pipeline';
import { TenantDetails } from './pages/TenantDetails';
import { Metrics } from './pages/Metrics';

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Overview />} />
        <Route path="/tenants" element={<Tenants />} />
        <Route path="/tenants/:tenantId" element={<TenantDetails />} />
        <Route path="/denials" element={<Denials />} />
        <Route path="/health" element={<Health />} />
        <Route path="/pipeline" element={<Pipeline />} />
        <Route path="/metrics" element={<Metrics />} />
      </Routes>
    </Layout>
  );
}

export default App; 