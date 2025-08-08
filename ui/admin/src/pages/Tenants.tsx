import React from 'react';
import { useQuery } from '@tanstack/react-query';

interface Tenant {
  id: string;
  name: string;
  enforcement: { enabled: boolean; burstPctOverride?: number };
}

export function Tenants() {
  const { data, isLoading, error } = useQuery('tenants', fetchTenants);

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Failed to load tenants</div>;

  const tenants: Tenant[] = data?.tenants ?? [];

  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">Tenants</h2>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b">
              <th className="text-left py-2 px-3">ID</th>
              <th className="text-left py-2 px-3">Name</th>
              <th className="text-left py-2 px-3">Enforcement</th>
            </tr>
          </thead>
          <tbody>
            {tenants.map(t => (
              <tr key={t.id} className="border-b">
                <td className="py-2 px-3 font-mono">{t.id}</td>
                <td className="py-2 px-3">{t.name}</td>
                <td className="py-2 px-3">{t.enforcement.enabled ? 'Enabled' : 'Disabled'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

async function fetchTenants() {
  const res = await fetch(`/api/tenants`);
  if (!res.ok) throw new Error('failed');
  return res.json();
}


