import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Toaster } from '@/components/ui/toaster';
import { Layout } from '@/components/Layout';
import { Overview } from '@/pages/Overview';
import { Tenants } from '@/pages/Tenants';
import { Denials } from '@/pages/Denials';
import { Health } from '@/pages/Health';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router>
        <Layout>
          <Routes>
            <Route path="/" element={<Overview />} />
            <Route path="/tenants" element={<Tenants />} />
            <Route path="/denials" element={<Denials />} />
            <Route path="/health" element={<Health />} />
          </Routes>
        </Layout>
        <Toaster />
      </Router>
    </QueryClientProvider>
  );
}

export default App; 