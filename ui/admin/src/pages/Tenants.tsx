
import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { 
  TrendingUp, 
  TrendingDown, 
  Activity, 
  Users, 
  RefreshCw, 
  ExternalLink, 
  Clock, 
  AlertTriangle, 
  CheckCircle, 
  XCircle, 
  Info,
  Shield,
  Zap,
  Database,
  BarChart3,
  Target,
  Gauge,
  FileText,
  Hash,
  Tag,
  Cpu,
  HardDrive,
  Network,
  Timer,
  AlertCircle,
  Filter,
  Settings,
  Eye,
  EyeOff,
  Play,
  Pause,
  RotateCcw
} from 'lucide-react';

// Utility function to format bytes in human-readable format
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Utility function to format samples per second
function formatSamplesPerSec(samples: number): string {
  if (samples >= 1000000) {
    return (samples / 1000000).toFixed(1) + 'M';
  } else if (samples >= 1000) {
    return (samples / 1000).toFixed(1) + 'K';
  }
  return samples.toFixed(1);
}

// Enhanced status function with more granular states
function getStatusInfo(enabled: boolean, denyRate: number, utilization: number, enforcement: any) {
  if (!enabled) {
    return {
      color: 'bg-gray-100 text-gray-800',
      icon: <EyeOff className="h-3 w-3" />,
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
  
  if (utilization > 90) {
    return {
      color: 'bg-red-100 text-red-800',
      icon: <AlertTriangle className="h-3 w-3" />,
      text: 'Critical Usage',
      description: `Critical utilization (${utilization.toFixed(1)}%) - immediate action needed`
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
  
  if (utilization > 60) {
    return {
      color: 'bg-blue-100 text-blue-800',
      icon: <Info className="h-3 w-3" />,
      text: 'Moderate Usage',
      description: `Moderate utilization (${utilization.toFixed(1)}%) - within safe limits`
    };
  }
  
  return {
    color: 'bg-green-100 text-green-800',
    icon: <CheckCircle className="h-3 w-3" />,
    text: 'Healthy',
    description: 'Operating within normal limits'
  };
}

// Enhanced interfaces for comprehensive tenant data
interface TenantLimits {
  samples_per_second: number;
  burst_pct: number;
  max_body_bytes: number;
  max_labels_per_series: number;
  max_label_value_length: number;
  max_series_per_request: number;
  max_series_per_metric?: number; // New per-metric limit
}

interface TenantMetrics {
  rps: number;
  bytes_per_sec: number;
  samples_per_sec: number;
  deny_rate: number;
  allow_rate: number;
  utilization_pct: number;
  avg_response_time?: number;
}

interface EnforcementConfig {
  enabled: boolean;
  burst_pct_override?: number;
  enforce_samples_per_second?: boolean;
  enforce_max_body_bytes?: boolean;
  enforce_max_labels_per_series?: boolean;
  enforce_max_series_per_request?: boolean;
  enforce_max_series_per_metric?: boolean;
  enforce_bytes_per_second?: boolean;
}

interface Tenant {
  id: string;
  name: string;
  limits: TenantLimits;
  metrics: TenantMetrics;
  enforcement: EnforcementConfig;
}

interface TenantsResponse {
  tenants: Tenant[];
  time_range: string;
  data_freshness: string;
}

export function Tenants() {
  const [timeRange, setTimeRange] = useState('15m');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [sortBy, setSortBy] = useState<'name' | 'rps' | 'samples' | 'deny_rate' | 'utilization'>('rps');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  const { data, isLoading, error, refetch } = useQuery<TenantsResponse>({ 
    queryKey: ['tenants', timeRange], 
    queryFn: () => fetchTenants(timeRange),
    refetchInterval: 30000, // Auto-refresh every 30 seconds
    refetchIntervalInBackground: true,
    staleTime: 15000, // Consider data stale after 15 seconds
    cacheTime: 60000 // Keep in cache for 1 minute
  });

  // Sort tenants based on current sort criteria
  const sortedTenants = React.useMemo(() => {
    if (!data?.tenants) return [];
    
    return [...data.tenants].sort((a, b) => {
      let aValue: number, bValue: number;
      
      switch (sortBy) {
        case 'name':
          return sortOrder === 'asc' 
            ? a.name.localeCompare(b.name)
            : b.name.localeCompare(a.name);
        case 'rps':
          aValue = a.metrics.rps;
          bValue = b.metrics.rps;
          break;
        case 'samples':
          aValue = a.metrics.samples_per_sec;
          bValue = b.metrics.samples_per_sec;
          break;
        case 'deny_rate':
          aValue = a.metrics.deny_rate;
          bValue = b.metrics.deny_rate;
          break;
        case 'utilization':
          aValue = a.metrics.utilization_pct;
          bValue = b.metrics.utilization_pct;
          break;
        default:
          return 0;
      }
      
      return sortOrder === 'asc' ? aValue - bValue : bValue - aValue;
    });
  }, [data?.tenants, sortBy, sortOrder]);

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-lg text-gray-600 flex items-center gap-2">
        <RefreshCw className="h-5 w-5 animate-spin" />
        Loading tenants...
      </div>
    </div>
  );

  if (error) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-lg text-red-600 flex items-center gap-2">
        <AlertCircle className="h-5 w-5" />
        Error loading tenants: {error instanceof Error ? error.message : 'Unknown error'}
      </div>
    </div>
  );

  const handleSort = (field: typeof sortBy) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(field);
      setSortOrder('desc');
    }
  };

  const getSortIcon = (field: typeof sortBy) => {
    if (sortBy !== field) return null;
    return sortOrder === 'asc' ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Tenants</h1>
          <p className="text-gray-600 mt-1">
            Monitor and manage tenant rate limiting and enforcement
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowAdvanced(!showAdvanced)}
            className="flex items-center gap-2 px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
          >
            {showAdvanced ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            {showAdvanced ? 'Hide' : 'Show'} Advanced
          </button>
          <button
            onClick={() => refetch()}
            className="flex items-center gap-2 px-3 py-2 text-sm bg-blue-100 hover:bg-blue-200 text-blue-700 rounded-md transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Refresh
          </button>
        </div>
      </div>

      {/* Time Range Selector */}
      <div className="flex items-center gap-4">
        <div className="flex items-center gap-2">
          <Clock className="h-4 w-4 text-gray-500" />
          <span className="text-sm font-medium text-gray-700">Time Range:</span>
        </div>
        <div className="flex gap-1">
          {['5m', '15m', '1h', '24h', '1w'].map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-3 py-1 text-sm rounded-md transition-colors ${
                timeRange === range
                  ? 'bg-blue-100 text-blue-700 font-medium'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {range}
            </button>
          ))}
        </div>
        {data?.data_freshness && (
          <div className="text-xs text-gray-500">
            Last updated: {new Date(data.data_freshness).toLocaleTimeString()}
          </div>
        )}
      </div>

      {/* Summary Stats */}
      {data?.tenants && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Total Tenants</p>
                  <p className="text-2xl font-bold text-gray-900">{data.tenants.length}</p>
                </div>
                <Users className="h-8 w-8 text-blue-500" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Active Enforcement</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {data.tenants.filter(t => t.enforcement.enabled).length}
                  </p>
                </div>
                <Shield className="h-8 w-8 text-green-500" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Rate Limited</p>
                  <p className="text-2xl font-bold text-red-600">
                    {data.tenants.filter(t => t.metrics.deny_rate > 0).length}
                  </p>
                </div>
                <XCircle className="h-8 w-8 text-red-500" />
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">High Usage</p>
                  <p className="text-2xl font-bold text-yellow-600">
                    {data.tenants.filter(t => t.metrics.utilization_pct > 80).length}
                  </p>
                </div>
                <AlertTriangle className="h-8 w-8 text-yellow-500" />
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tenants Table */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Tenant Details
          </CardTitle>
          <CardDescription>
            Comprehensive view of tenant metrics, limits, and enforcement status
          </CardDescription>
        </CardHeader>
        <CardContent>
          {sortedTenants.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <Users className="h-12 w-12 mx-auto mb-4 text-gray-300" />
              <p>No tenants found</p>
              <p className="text-sm">Tenants will appear here once they start sending metrics</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="text-left py-3 px-4 font-medium text-gray-700">
                      <button
                        onClick={() => handleSort('name')}
                        className="flex items-center gap-1 hover:text-gray-900 transition-colors"
                      >
                        Tenant Name {getSortIcon('name')}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">
                      <button
                        onClick={() => handleSort('rps')}
                        className="flex items-center gap-1 hover:text-gray-900 transition-colors"
                      >
                        RPS {getSortIcon('rps')}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">
                      <button
                        onClick={() => handleSort('samples')}
                        className="flex items-center gap-1 hover:text-gray-900 transition-colors"
                      >
                        Samples/sec {getSortIcon('samples')}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">
                      <button
                        onClick={() => handleSort('deny_rate')}
                        className="flex items-center gap-1 hover:text-gray-900 transition-colors"
                      >
                        Deny Rate {getSortIcon('deny_rate')}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">
                      <button
                        onClick={() => handleSort('utilization')}
                        className="flex items-center gap-1 hover:text-gray-900 transition-colors"
                      >
                        Utilization {getSortIcon('utilization')}
                      </button>
                    </th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">Status</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-700">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedTenants.map((tenant) => {
                    const statusInfo = getStatusInfo(
                      tenant.enforcement.enabled,
                      tenant.metrics.deny_rate,
                      tenant.metrics.utilization_pct,
                      tenant.enforcement
                    );
                    
                    return (
                      <tr key={tenant.id} className="border-b border-gray-100 hover:bg-gray-50">
                        <td className="py-4 px-4">
                          <div>
                            <div className="font-medium text-gray-900">{tenant.name}</div>
                            <div className="text-sm text-gray-500">ID: {tenant.id}</div>
                          </div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <Activity className="h-4 w-4 text-blue-500" />
                            <span className="font-medium">{tenant.metrics.rps.toFixed(1)}</span>
                          </div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <BarChart3 className="h-4 w-4 text-purple-500" />
                            <span className="font-medium">{formatSamplesPerSec(tenant.metrics.samples_per_sec)}</span>
                          </div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <XCircle className="h-4 w-4 text-red-500" />
                            <span className={`font-medium ${tenant.metrics.deny_rate > 0 ? 'text-red-600' : 'text-gray-600'}`}>
                              {tenant.metrics.deny_rate.toFixed(1)}/s
                            </span>
                          </div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <Gauge className="h-4 w-4 text-orange-500" />
                            <div>
                              <div className="font-medium">{tenant.metrics.utilization_pct.toFixed(1)}%</div>
                              <div className="w-16 bg-gray-200 rounded-full h-1.5">
                                <div 
                                  className={`h-1.5 rounded-full ${
                                    tenant.metrics.utilization_pct > 90 ? 'bg-red-500' :
                                    tenant.metrics.utilization_pct > 80 ? 'bg-yellow-500' :
                                    tenant.metrics.utilization_pct > 60 ? 'bg-blue-500' : 'bg-green-500'
                                  }`}
                                  style={{ width: `${Math.min(tenant.metrics.utilization_pct, 100)}%` }}
                                />
                              </div>
                            </div>
                          </div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${statusInfo.color}`}>
                            {statusInfo.icon}
                            {statusInfo.text}
                          </div>
                          <div className="text-xs text-gray-500 mt-1">{statusInfo.description}</div>
                        </td>
                        
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            <Link
                              to={`/tenants/${tenant.id}`}
                              className="flex items-center gap-1 px-2 py-1 text-xs bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors"
                            >
                              <ExternalLink className="h-3 w-3" />
                              Details
                            </Link>
                            <button
                              onClick={() => {
                                // Navigate to tenant details page for configuration
                                window.location.href = `/tenants/${tenant.id}`;
                              }}
                              className="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded hover:bg-gray-200 transition-colors"
                            >
                              <Settings className="h-3 w-3" />
                              Configure
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Advanced Metrics (when enabled) */}
      {showAdvanced && data?.tenants && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Settings className="h-5 w-5" />
              Advanced Metrics & Configuration
            </CardTitle>
            <CardDescription>
              Detailed enforcement settings and granular metrics
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {sortedTenants.map((tenant) => (
                <Card key={tenant.id} className="border border-gray-200">
                  <CardHeader className="pb-3">
                    <CardTitle className="text-lg">{tenant.name}</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    {/* Enforcement Status */}
                    <div>
                      <h4 className="font-medium text-gray-700 mb-2 flex items-center gap-2">
                        <Shield className="h-4 w-4" />
                        Enforcement Status
                      </h4>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="flex justify-between">
                          <span>Enabled:</span>
                          <span className={tenant.enforcement.enabled ? 'text-green-600' : 'text-gray-500'}>
                            {tenant.enforcement.enabled ? 'Yes' : 'No'}
                          </span>
                        </div>
                        {tenant.enforcement.enabled && (
                          <>
                            <div className="flex justify-between">
                              <span>Samples Limit:</span>
                              <span>{tenant.enforcement.enforce_samples_per_second ? 'Yes' : 'No'}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Body Size:</span>
                              <span>{tenant.enforcement.enforce_max_body_bytes ? 'Yes' : 'No'}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Labels:</span>
                              <span>{tenant.enforcement.enforce_max_labels_per_series ? 'Yes' : 'No'}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Series/Request:</span>
                              <span>{tenant.enforcement.enforce_max_series_per_request ? 'Yes' : 'No'}</span>
                            </div>
                            {tenant.enforcement.enforce_max_series_per_metric && (
                              <div className="flex justify-between">
                                <span>Series/Metric:</span>
                                <span>Yes</span>
                              </div>
                            )}
                          </>
                        )}
                      </div>
                    </div>

                    {/* Current Limits */}
                    <div>
                      <h4 className="font-medium text-gray-700 mb-2 flex items-center gap-2">
                        <Target className="h-4 w-4" />
                        Current Limits
                      </h4>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="flex justify-between">
                          <span>Samples/sec:</span>
                          <span>{formatSamplesPerSec(tenant.limits.samples_per_second)}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Burst %:</span>
                          <span>{tenant.limits.burst_pct}%</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Body Size:</span>
                          <span>{formatBytes(tenant.limits.max_body_bytes)}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Labels/Series:</span>
                          <span>{tenant.limits.max_labels_per_series}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Series/Request:</span>
                          <span>{tenant.limits.max_series_per_request}</span>
                        </div>
                        {tenant.limits.max_series_per_metric && (
                          <div className="flex justify-between">
                            <span>Series/Metric:</span>
                            <span>{tenant.limits.max_series_per_metric}</span>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Performance Metrics */}
                    <div>
                      <h4 className="font-medium text-gray-700 mb-2 flex items-center gap-2">
                        <Zap className="h-4 w-4" />
                        Performance
                      </h4>
                      <div className="grid grid-cols-2 gap-2 text-sm">
                        <div className="flex justify-between">
                          <span>Bytes/sec:</span>
                          <span>{formatBytes(tenant.metrics.bytes_per_sec)}</span>
                        </div>
                        <div className="flex justify-between">
                          <span>Allow Rate:</span>
                          <span>{tenant.metrics.allow_rate.toFixed(1)}/s</span>
                        </div>
                        {tenant.metrics.avg_response_time && (
                          <div className="flex justify-between">
                            <span>Avg Response:</span>
                            <span>{(tenant.metrics.avg_response_time * 1000).toFixed(1)}ms</span>
                          </div>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

async function fetchTenants(timeRange: string): Promise<TenantsResponse> {
  const res = await fetch(`/api/tenants?range=${timeRange}`);
  if (!res.ok) {
    throw new Error(`Failed to fetch tenants: ${res.statusText}`);
  }
  return res.json();
}


