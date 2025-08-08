
import { Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Overview } from './pages/Overview';
import { Tenants } from './pages/Tenants';
import { Denials } from './pages/Denials';
import { Health } from './pages/Health';

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Overview />} />
        <Route path="/tenants" element={<Tenants />} />
        <Route path="/denials" element={<Denials />} />
        <Route path="/health" element={<Health />} />
      </Routes>
    </Layout>
  );
}

export default App; 