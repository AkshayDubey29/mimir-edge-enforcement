
import { useQuery } from '@tanstack/react-query';

// Utility function to format bytes in human-readable format
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

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
  const { data, isLoading, error } = useQuery<TenantsResponse>({ 
    queryKey: ['tenants'], 
    queryFn: fetchTenants,
    refetchInterval: 5000, // Auto-refresh every 5 seconds
    refetchIntervalInBackground: true
  });

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
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">Auto-refresh (5s)</span>
          </div>
          <div className="text-sm text-gray-500">
            Total: {tenants.length}
          </div>
        </div>
      </div>
      
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant Info</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Rate Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Size Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Series Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Current Metrics</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {tenants.map((tenant: Tenant) => (
                <tr key={tenant.id} className="hover:bg-gray-50">
                  {/* Tenant Info */}
                  <td className="py-4 px-4">
                    <div>
                      <div className="font-mono text-sm font-medium text-gray-900">{tenant.id}</div>
                      <div className="text-sm text-gray-500">{tenant.name || 'No display name'}</div>
                    </div>
                  </td>
                  
                  {/* Rate Limits */}
                  <td className="py-4 px-4">
                    <div className="space-y-1">
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Samples/sec:</span>{' '}
                        <span className="font-mono">{tenant.limits.samples_per_second.toLocaleString()}</span>
                      </div>
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Burst:</span>{' '}
                        <span className="font-mono">{(tenant.limits.burst_pct * 100).toFixed(0)}%</span>
                      </div>
                    </div>
                  </td>
                  
                  {/* Size Limits */}
                  <td className="py-4 px-4">
                    <div className="space-y-1">
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Max Body:</span>{' '}
                        <span className="font-mono">{formatBytes(tenant.limits.max_body_bytes)}</span>
                      </div>
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Label Length:</span>{' '}
                        <span className="font-mono">{tenant.limits.max_label_value_length.toLocaleString()}</span>
                      </div>
                    </div>
                  </td>
                  
                  {/* Series Limits */}
                  <td className="py-4 px-4">
                    <div className="space-y-1">
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Labels/Series:</span>{' '}
                        <span className="font-mono">{tenant.limits.max_labels_per_series}</span>
                      </div>
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Series/Request:</span>{' '}
                        <span className="font-mono">{tenant.limits.max_series_per_request.toLocaleString()}</span>
                      </div>
                    </div>
                  </td>
                  
                  {/* Current Metrics */}
                  <td className="py-4 px-4">
                    <div className="space-y-1">
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Allow Rate:</span>{' '}
                        <span className="font-mono text-green-600">{tenant.metrics.allow_rate.toFixed(1)}/s</span>
                      </div>
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Deny Rate:</span>{' '}
                        <span className={`font-mono ${tenant.metrics.deny_rate > 0 ? 'text-red-600' : 'text-green-600'}`}>
                          {tenant.metrics.deny_rate.toFixed(1)}/s
                        </span>
                      </div>
                      <div className="text-sm">
                        <span className="font-medium text-gray-700">Utilization:</span>{' '}
                        <span className="font-mono">{tenant.metrics.utilization_pct.toFixed(1)}%</span>
                      </div>
                    </div>
                  </td>
                  
                  {/* Status */}
                  <td className="py-4 px-4">
                    <div className="space-y-2">
                      <span className={`inline-block px-2 py-1 text-xs rounded font-medium ${
                        tenant.enforcement.enabled 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-gray-100 text-gray-800'
                      }`}>
                        {tenant.enforcement.enabled ? 'Enforced' : 'Monitoring'}
                      </span>
                      {tenant.enforcement.burst_pct_override && (
                        <div className="text-xs text-orange-600">
                          Burst Override: {(tenant.enforcement.burst_pct_override * 100).toFixed(0)}%
                        </div>
                      )}
                      {tenant.metrics.deny_rate > 0 && (
                        <div className="text-xs">
                          <span className="inline-block w-2 h-2 bg-red-500 rounded-full mr-1"></span>
                          <span className="text-red-600">Active Denials</span>
                        </div>
                      )}
                    </div>
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


