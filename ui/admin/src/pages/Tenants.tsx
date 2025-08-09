
import { useQuery } from '@tanstack/react-query';

interface TenantLimits {
  samples_per_second: number;
  burst_pct: number;
  max_body_bytes: number;
  max_labels_per_series: number;
  max_label_value_length: number;
  max_series_per_request: number;
}

interface TenantMetrics {
  rps: number;
  bytes_per_sec: number;
  samples_per_sec: number;
  deny_rate: number;
  allow_rate: number;
  utilization_pct: number;
}

interface Tenant {
  id: string;
  name: string;
  limits: TenantLimits;
  metrics: TenantMetrics;
  enforcement: { enabled: boolean; burst_pct_override?: number };
}

interface TenantsResponse {
  tenants: Tenant[];
}

export function Tenants() {
  const { data, isLoading, error } = useQuery<TenantsResponse>({ queryKey: ['tenants'], queryFn: fetchTenants });

  if (isLoading) return <div className="flex items-center justify-center h-64"><div className="text-lg text-gray-600">Loading tenants...</div></div>;
  if (error) return <div className="flex items-center justify-center h-64"><div className="text-lg text-red-600">Failed to load tenants: {error instanceof Error ? error.message : 'Unknown error'}</div></div>;

  const tenants: Tenant[] = data?.tenants ?? [];

  if (tenants.length === 0) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-900">Tenants</h1>
          <div className="text-sm text-gray-500">
            Total: {tenants.length}
          </div>
        </div>
        
        <div className="flex items-center justify-center h-64 bg-gray-50 rounded-lg">
          <div className="text-center">
            <div className="text-lg text-gray-600 mb-2">No tenants found</div>
            <div className="text-sm text-gray-500">
              Make sure overrides-sync is running and has access to Mimir ConfigMap
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Tenants</h1>
        <div className="text-sm text-gray-500">
          Total: {tenants.length}
        </div>
      </div>
      
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant ID</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Name</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Samples/sec Limit</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Allow Rate</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Deny Rate</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Enforcement</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {tenants.map((tenant: Tenant) => (
                <tr key={tenant.id} className="hover:bg-gray-50">
                  <td className="py-3 px-4 font-mono text-sm">{tenant.id}</td>
                  <td className="py-3 px-4">{tenant.name || tenant.id}</td>
                  <td className="py-3 px-4">{tenant.limits.samples_per_second.toLocaleString()}</td>
                  <td className="py-3 px-4">{tenant.metrics.allow_rate.toFixed(1)}</td>
                  <td className="py-3 px-4">
                    <span className={`inline-block px-2 py-1 text-xs rounded ${
                      tenant.metrics.deny_rate > 0 ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
                    }`}>
                      {tenant.metrics.deny_rate.toFixed(1)}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <span className={`inline-block px-2 py-1 text-xs rounded font-medium ${
                      tenant.enforcement.enabled 
                        ? 'bg-green-100 text-green-800' 
                        : 'bg-gray-100 text-gray-800'
                    }`}>
                      {tenant.enforcement.enabled ? 'Enabled' : 'Disabled'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

async function fetchTenants() {
  const res = await fetch(`/api/tenants`);
  if (!res.ok) throw new Error('failed');
  return res.json();
}


