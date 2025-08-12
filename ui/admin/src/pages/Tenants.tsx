
import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { TrendingUp, TrendingDown, Activity, Users, RefreshCw, ExternalLink, Clock, AlertTriangle, CheckCircle, XCircle, Info } from 'lucide-react';

// Utility function to format bytes in human-readable format
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Utility function to get status color and description
function getStatusInfo(enabled: boolean, denyRate: number, utilization: number) {
  if (!enabled) {
    return {
      color: 'bg-gray-100 text-gray-800',
      icon: <Info className="h-3 w-3" />,
      text: 'Monitoring Only',
      description: 'Rate limiting is disabled - only monitoring active'
    };
  }
  
  if (denyRate > 0) {
    return {
      color: 'bg-red-100 text-red-800',
      icon: <XCircle className="h-3 w-3" />,
      text: 'Rate Limited',
      description: `Requests are being denied (${denyRate.toFixed(1)}/s)`
    };
  }
  
  if (utilization > 80) {
    return {
      color: 'bg-yellow-100 text-yellow-800',
      icon: <AlertTriangle className="h-3 w-3" />,
      text: 'High Usage',
      description: `High utilization (${utilization.toFixed(1)}%) - approaching limits`
    };
  }
  
  return {
    color: 'bg-green-100 text-green-800',
    icon: <CheckCircle className="h-3 w-3" />,
    text: 'Healthy',
    description: 'Operating within normal limits'
  };
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
  time_range: string;
  data_freshness: string;
}

export function Tenants() {
  const [timeRange, setTimeRange] = useState('15m');

  const { data, isLoading, error } = useQuery<TenantsResponse>({ 
    queryKey: ['tenants', timeRange], 
    queryFn: () => fetchTenants(timeRange),
    refetchInterval: 30000, // Auto-refresh every 30 seconds (less frequent for stability)
    refetchIntervalInBackground: true,
    staleTime: 15000, // Consider data stale after 15 seconds
    cacheTime: 60000 // Keep in cache for 1 minute
  });

  if (isLoading) return <div className="flex items-center justify-center h-64"><div className="text-lg text-gray-600">Loading tenants...</div></div>;
  if (error) return <div className="flex items-center justify-center h-64"><div className="text-lg text-red-600">Failed to load tenants: {error instanceof Error ? error.message : 'Unknown error'}</div></div>;

  const tenants: Tenant[] = data?.tenants ?? [];
  const dataFreshness = data?.data_freshness ? new Date(data.data_freshness).toLocaleTimeString() : 'Unknown';

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
          {/* Time Range Selector */}
          <div className="flex items-center space-x-2">
            <Clock className="h-4 w-4 text-gray-500" />
            <select 
              value={timeRange} 
              onChange={(e) => setTimeRange(e.target.value)}
              className="text-sm border border-gray-300 rounded px-2 py-1 bg-white"
            >
              <option value="15m">Last 15 minutes</option>
              <option value="1h">Last 1 hour</option>
              <option value="24h">Last 24 hours</option>
              <option value="1w">Last 1 week</option>
            </select>
          </div>
          
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">Auto-refresh (30s)</span>
          </div>
          <div className="text-sm text-gray-500">
            Total: {tenants.length} | Last updated: {dataFreshness}
          </div>
        </div>
      </div>

      {/* Status Legend */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-lg">Status Guide</CardTitle>
          <CardDescription>Understanding tenant status indicators</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-green-500 rounded-full"></div>
              <span className="text-sm font-medium">Healthy</span>
              <span className="text-xs text-gray-500">Operating normally</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <span className="text-sm font-medium">High Usage</span>
              <span className="text-xs text-gray-500">Approaching limits</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-red-500 rounded-full"></div>
              <span className="text-sm font-medium">Rate Limited</span>
              <span className="text-xs text-gray-500">Requests being denied</span>
            </div>
            <div className="flex items-center space-x-2">
              <div className="w-3 h-3 bg-gray-500 rounded-full"></div>
              <span className="text-sm font-medium">Monitoring</span>
              <span className="text-xs text-gray-500">Limits disabled</span>
            </div>
          </div>
        </CardContent>
      </Card>
      
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant Info</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Rate Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Size Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Series Limits</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Current Metrics ({timeRange})</th>
                <th className="text-left py-3 px-4 font-medium text-gray-900">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {tenants.map((tenant: Tenant) => {
                const statusInfo = getStatusInfo(tenant.enforcement.enabled, tenant.metrics.deny_rate, tenant.metrics.utilization_pct);
                
                return (
                  <tr key={tenant.id} className="hover:bg-gray-50">
                    {/* Tenant Info */}
                    <td className="py-4 px-4">
                      <div>
                        <div className="flex items-center space-x-2">
                          <div className="font-mono text-sm font-medium text-gray-900">{tenant.id}</div>
                          <Link 
                            to={`/tenants/${tenant.id}`}
                            className="text-blue-600 hover:text-blue-800 transition-colors"
                            title="View detailed tenant information"
                          >
                            <ExternalLink className="h-3 w-3" />
                          </Link>
                        </div>
                        <div className="text-sm text-gray-500">{tenant.name || 'No display name'}</div>
                      </div>
                    </td>
                    
                    {/* Rate Limits */}
                    <td className="py-4 px-4">
                      <div className="space-y-1">
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Samples/sec:</span>{' '}
                          <span className="font-mono">{tenant.limits.samples_per_second > 0 ? tenant.limits.samples_per_second.toLocaleString() : 'Unlimited'}</span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Burst:</span>{' '}
                          <span className="font-mono">{tenant.limits.burst_pct > 0 ? `${(tenant.limits.burst_pct * 100).toFixed(0)}%` : 'No burst'}</span>
                        </div>
                      </div>
                    </td>
                    
                    {/* Size Limits */}
                    <td className="py-4 px-4">
                      <div className="space-y-1">
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Max Body:</span>{' '}
                          <span className="font-mono">{tenant.limits.max_body_bytes > 0 ? formatBytes(tenant.limits.max_body_bytes) : 'Unlimited'}</span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Label Length:</span>{' '}
                          <span className="font-mono">{tenant.limits.max_label_value_length > 0 ? tenant.limits.max_label_value_length.toLocaleString() : 'Unlimited'}</span>
                        </div>
                      </div>
                    </td>
                    
                    {/* Series Limits */}
                    <td className="py-4 px-4">
                      <div className="space-y-1">
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Labels/Series:</span>{' '}
                          <span className="font-mono">{tenant.limits.max_labels_per_series > 0 ? tenant.limits.max_labels_per_series : 'Unlimited'}</span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Series/Request:</span>{' '}
                          <span className="font-mono">{tenant.limits.max_series_per_request > 0 ? tenant.limits.max_series_per_request.toLocaleString() : 'Unlimited'}</span>
                        </div>
                      </div>
                    </td>
                    
                    {/* Current Metrics */}
                    <td className="py-4 px-4">
                      <div className="space-y-1">
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">RPS:</span>{' '}
                          <span className="font-mono text-blue-600" title="Requests Per Second">
                            {typeof tenant.metrics.rps === 'number' ? tenant.metrics.rps.toFixed(2) : '0.00'}
                          </span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Samples/sec:</span>{' '}
                          <span className="font-mono text-blue-600">
                            {typeof tenant.metrics.samples_per_sec === 'number' ? tenant.metrics.samples_per_sec.toFixed(2) : '0.00'}
                          </span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Allow Rate:</span>{' '}
                          <span className="font-mono text-green-600">{tenant.metrics.allow_rate.toFixed(1)}%</span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Deny Rate:</span>{' '}
                          <span className={`font-mono ${tenant.metrics.deny_rate > 0 ? 'text-red-600' : 'text-green-600'}`}>
                            {tenant.metrics.deny_rate.toFixed(1)}%
                          </span>
                        </div>
                        <div className="text-sm">
                          <span className="font-medium text-gray-700">Utilization:</span>{' '}
                          <span className={`font-mono ${tenant.metrics.utilization_pct > 80 ? 'text-yellow-600' : tenant.metrics.utilization_pct > 0 ? 'text-green-600' : 'text-gray-600'}`}>
                            {tenant.metrics.utilization_pct.toFixed(1)}%
                          </span>
                        </div>
                      </div>
                    </td>
                    
                    {/* Status */}
                    <td className="py-4 px-4">
                      <div className="space-y-2">
                        <div className="flex items-center space-x-1">
                          {statusInfo.icon}
                          <span className={`inline-block px-2 py-1 text-xs rounded font-medium ${statusInfo.color}`}>
                            {statusInfo.text}
                          </span>
                        </div>
                        <div className="text-xs text-gray-600 max-w-32">
                          {statusInfo.description}
                        </div>
                        {tenant.enforcement.burst_pct_override && tenant.enforcement.burst_pct_override > 0 && (
                          <div className="text-xs text-orange-600">
                            Burst Override: {(tenant.enforcement.burst_pct_override * 100).toFixed(0)}%
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

async function fetchTenants(timeRange: string = '15m') {
  const res = await fetch(`/api/tenants?range=${timeRange}`);
  if (!res.ok) throw new Error('Failed to fetch tenants');
  return res.json();
}


