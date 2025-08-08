import React from 'react';
import { useQuery } from 'react-query';

interface Denial {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_samples: number;
  observed_body_bytes: number;
}

export function Denials() {
  const { data, isLoading, error } = useQuery('denials', fetchDenials);
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Failed to load denials</div>;
  const denials: Denial[] = data?.denials ?? [];
  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">Recent Denials</h2>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b">
              <th className="text-left py-2 px-3">Time</th>
              <th className="text-left py-2 px-3">Tenant</th>
              <th className="text-left py-2 px-3">Reason</th>
              <th className="text-left py-2 px-3">Samples</th>
              <th className="text-left py-2 px-3">Bytes</th>
            </tr>
          </thead>
          <tbody>
            {denials.map((d, i) => (
              <tr key={i} className="border-b">
                <td className="py-2 px-3">{new Date(d.timestamp).toLocaleString()}</td>
                <td className="py-2 px-3 font-mono">{d.tenant_id}</td>
                <td className="py-2 px-3">{d.reason}</td>
                <td className="py-2 px-3">{d.observed_samples}</td>
                <td className="py-2 px-3">{d.observed_body_bytes}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

async function fetchDenials() {
  const res = await fetch(`/api/denials?since=1h&tenant=*`);
  if (!res.ok) throw new Error('failed');
  return res.json();
}


