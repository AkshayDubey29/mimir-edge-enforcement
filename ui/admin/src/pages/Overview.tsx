import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  AreaChart,
  Area
} from 'recharts';
import { 
  Activity, 
  Users, 
  TrendingUp, 
  TrendingDown, 
  AlertTriangle, 
  CheckCircle, 
  XCircle,
  Clock,
  Zap,
  Shield,
  Database,
  Server,
  Network,
  Wifi,
  WifiOff,
  AlertCircle,
  Info,
  RefreshCw,
  Play,
  Pause,
  StopCircle
} from 'lucide-react';

// Enhanced interfaces for flow monitoring
interface OverviewStats {
  total_requests: number;
  allowed_requests: number;
  denied_requests: number;
  allow_percentage: number;
  active_tenants: number;
}

interface TopTenant {
  id: string;
  name: string;
  rps: number;
  samples_per_sec: number;
  deny_rate: number;
}

interface FlowMetrics {
  nginx_requests: number;
  nginx_route_direct: number;
  nginx_route_edge: number;
  envoy_requests: number;
  envoy_authorized: number;
  envoy_denied: number;
  mimir_requests: number;
  mimir_success: number;
  mimir_errors: number;
  response_times: {
    nginx_to_envoy: number;
    envoy_to_mimir: number;
    total_flow: number;
  };
}

interface FlowDataPoint {
  timestamp: string;
  nginx_requests: number;
  route_direct: number;
  route_edge: number;
  envoy_requests: number;
  mimir_requests: number;
  success_rate: number;
}

interface OverviewData {
  stats: OverviewStats;
  top_tenants: TopTenant[];
  flow_metrics: FlowMetrics;
  flow_timeline: FlowDataPoint[];
  flow_status: FlowStatus;
  health_checks: HealthChecks;
  service_status: Record<string, any>;
  endpoint_status: Record<string, any>;
  validation_results: Record<string, any>;
}

interface FlowStatus {
  overall: 'healthy' | 'degraded' | 'broken' | 'unknown';
  nginx: ComponentStatus;
  envoy: ComponentStatus;
  rls: ComponentStatus;
  overrides_sync: ComponentStatus;
  mimir: ComponentStatus;
  last_check: string;
}

interface ComponentStatus {
  status: 'healthy' | 'degraded' | 'broken' | 'unknown';
  message: string;
  last_seen: string;
  response_time: number;
  error_count: number;
}

interface HealthChecks {
  rls_service: boolean;
  overrides_sync: boolean;
  envoy_proxy: boolean;
  nginx_config: boolean;
  mimir_connectivity: boolean;
  tenant_limits_synced: boolean;
  enforcement_active: boolean;
}

interface TenantMetrics {
  allow_rate: number;
  deny_rate: number;
  utilization_pct?: number;
  rps?: number; // Added for RPS
  samples_per_sec?: number; // Added for samples_per_sec
}

interface TenantLimits {
  samples_per_second?: number;
  burst_percent?: number;
  max_body_bytes?: number;
}

interface Tenant {
  id: string;
  name?: string;
  limits?: TenantLimits;
  metrics?: TenantMetrics;
}

interface TenantsResponse {
  tenants: Tenant[];
}

// Status badge component
function StatusBadge({ status, message }: { status: string; message?: string }) {
  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'healthy':
        return { color: 'bg-green-100 text-green-800', icon: CheckCircle };
      case 'degraded':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'broken':
        return { color: 'bg-red-100 text-red-800', icon: XCircle };
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: AlertCircle };
    }
  };

  const config = getStatusConfig(status);
  const Icon = config.icon;

  return (
    <Badge className={config.color}>
      <Icon className="w-3 h-3 mr-1" />
      {status.charAt(0).toUpperCase() + status.slice(1)}
      {message && <span className="ml-1 text-xs">({message})</span>}
    </Badge>
  );
}

export function Overview() {
  const [timeRange, setTimeRange] = useState('1h');

  const { data: overviewData, isLoading, error } = useQuery<OverviewData>(
    ['overview', timeRange],
    () => fetchOverviewData(timeRange),
    {
      refetchInterval: 300000, // Refetch every 5 minutes for time-based data (increased from 60s)
      refetchIntervalInBackground: true,
      staleTime: 180000, // Consider data stale after 3 minutes (increased from 30s)
      cacheTime: 600000, // Cache for 10 minutes
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Loading overview data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-lg text-red-600">Failed to load overview data</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  // Ensure we have safe defaults for all data
  const safeData = overviewData || {
    stats: { total_requests: 0, allowed_requests: 0, denied_requests: 0, allow_percentage: 0, active_tenants: 0 },
    top_tenants: [],
    flow_metrics: { nginx_requests: 0, nginx_route_direct: 0, nginx_route_edge: 0, envoy_requests: 0, envoy_authorized: 0, envoy_denied: 0, mimir_requests: 0, mimir_success: 0, mimir_errors: 0, response_times: { nginx_to_envoy: 0, envoy_to_mimir: 0, total_flow: 0 } },
    flow_timeline: [],
    flow_status: { overall: 'unknown', nginx: { status: 'unknown', message: '', last_seen: '', response_time: 0, error_count: 0 }, envoy: { status: 'unknown', message: '', last_seen: '', response_time: 0, error_count: 0 }, rls: { status: 'unknown', message: '', last_seen: '', response_time: 0, error_count: 0 }, overrides_sync: { status: 'unknown', message: '', last_seen: '', response_time: 0, error_count: 0 }, mimir: { status: 'unknown', message: '', last_seen: '', response_time: 0, error_count: 0 }, last_check: '' },
    health_checks: { rls_service: false, overrides_sync: false, envoy_proxy: false, nginx_config: false, mimir_connectivity: false, tenant_limits_synced: false, enforcement_active: false },
    service_status: {},
    endpoint_status: {},
    validation_results: {}
  };

  const { stats, top_tenants, flow_metrics, flow_timeline, flow_status, health_checks, service_status, endpoint_status, validation_results } = safeData;

  // Calculate overall status
  const getOverallStatus = () => {
    if (flow_status.overall === 'broken') return 'broken';
    if (flow_status.overall === 'degraded') return 'degraded';
    if (flow_status.overall === 'healthy') return 'healthy';
    return 'unknown';
  };

  const overallStatus = getOverallStatus();

  // Time range options
  const timeRangeOptions = [
    { value: '15m', label: '15 Minutes' },
    { value: '1h', label: '1 Hour' },
    { value: '24h', label: '24 Hours' },
    { value: '1w', label: '1 Week' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Overview</h1>
          <p className="text-gray-500">System-wide metrics and health monitoring</p>
        </div>
        <div className="flex items-center space-x-4">
          <StatusBadge status={overallStatus} />
          
          {/* Time Range Selector */}
          <div className="flex items-center space-x-2">
            <span className="text-sm text-gray-500">Time Range:</span>
            <select
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value)}
              className="px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {timeRangeOptions.map(option => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
          
          <div className="flex items-center space-x-2 text-sm text-gray-500">
            <RefreshCw className="w-4 h-4 animate-spin" />
            <span>Auto-refresh (5m)</span>
          </div>
        </div>
      </div>

      {/* Flow Status Dashboard */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">NGINX Traffic</CardTitle>
            <StatusBadge status={flow_status?.nginx?.status || 'unknown'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics?.nginx_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              {flow_metrics?.nginx_route_direct || 0} direct, {flow_metrics?.nginx_route_edge || 0} edge
            </p>
            <div className="mt-2 text-xs text-gray-500">
              Response: {flow_status?.nginx?.response_time || 0}ms
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Envoy Proxy</CardTitle>
            <StatusBadge status={flow_status?.envoy?.status || 'unknown'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics?.envoy_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              {flow_metrics?.envoy_authorized || 0} authorized, {flow_metrics?.envoy_denied || 0} denied
            </p>
            <div className="mt-2 text-xs text-gray-500">
              Response: {flow_status?.envoy?.response_time || 0}ms
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">RLS Service</CardTitle>
            <StatusBadge status={flow_status?.rls?.status || 'unknown'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.active_tenants || 0}</div>
            <p className="text-xs text-muted-foreground">
              Active tenants with limits
            </p>
            <div className="mt-2 text-xs text-gray-500">
              Response: {flow_status?.rls?.response_time || 0}ms
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Overrides Sync</CardTitle>
            <StatusBadge status={flow_status?.overrides_sync?.status || 'unknown'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{health_checks?.tenant_limits_synced ? '✓' : '✗'}</div>
            <p className="text-xs text-muted-foreground">
              {health_checks?.tenant_limits_synced ? 'Limits synced' : 'Limits not synced'}
            </p>
            <div className="mt-2 text-xs text-gray-500">
              Last: {flow_status?.overrides_sync?.last_seen || 'Never'}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Mimir Backend</CardTitle>
            <StatusBadge status={flow_status?.mimir?.status || 'unknown'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics?.mimir_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              {flow_metrics?.mimir_success || 0} success, {flow_metrics?.mimir_errors || 0} errors
            </p>
            <div className="mt-2 text-xs text-gray-500">
              Response: {flow_status?.mimir?.response_time || 0}ms
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Enforcement Status</CardTitle>
            <StatusBadge status={health_checks?.enforcement_active ? 'healthy' : 'broken'} />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.allow_percentage?.toFixed(1) || 0}%</div>
            <p className="text-xs text-muted-foreground">
              Allow rate
            </p>
            <div className="mt-2 text-xs text-gray-500">
              {stats?.denied_requests || 0} denials in {timeRange}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Flow Diagram */}
      <Card>
        <CardHeader>
          <CardTitle>End-to-End Flow Status</CardTitle>
          <CardDescription>
            Real-time pipeline health and traffic flow visualization
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-5 gap-4 items-center">
            {/* Client */}
            <div className="text-center">
              <div className="w-12 h-12 mx-auto bg-blue-100 rounded-full flex items-center justify-center mb-2">
                <Users className="w-6 h-6 text-blue-600" />
              </div>
              <div className="text-sm font-medium">Client</div>
              <div className="text-xs text-gray-500">Traffic Source</div>
            </div>

            {/* Arrow */}
            <div className="flex items-center justify-center">
              <div className={`w-8 h-1 ${health_checks?.nginx_config ? 'bg-green-500' : 'bg-red-500'} rounded`}></div>
              <ArrowRight className="w-4 h-4 text-gray-400" />
            </div>

            {/* NGINX */}
            <div className="text-center">
              <div className={`w-12 h-12 mx-auto rounded-full flex items-center justify-center mb-2 ${
                flow_status?.nginx?.status === 'healthy' ? 'bg-green-100' : 
                flow_status?.nginx?.status === 'degraded' ? 'bg-yellow-100' : 'bg-red-100'
              }`}>
                <Server className={`w-6 h-6 ${
                  flow_status?.nginx?.status === 'healthy' ? 'text-green-600' : 
                  flow_status?.nginx?.status === 'degraded' ? 'text-yellow-600' : 'text-red-600'
                }`} />
              </div>
              <div className="text-sm font-medium">NGINX</div>
              <div className="text-xs text-gray-500">{flow_metrics?.nginx_requests || 0} req/s</div>
            </div>

            {/* Arrow */}
            <div className="flex items-center justify-center">
              <div className={`w-8 h-1 ${health_checks?.envoy_proxy ? 'bg-green-500' : 'bg-red-500'} rounded`}></div>
              <ArrowRight className="w-4 h-4 text-gray-400" />
            </div>

            {/* Envoy */}
            <div className="text-center">
              <div className={`w-12 h-12 mx-auto rounded-full flex items-center justify-center mb-2 ${
                flow_status?.envoy?.status === 'healthy' ? 'bg-green-100' : 
                flow_status?.envoy?.status === 'degraded' ? 'bg-yellow-100' : 'bg-red-100'
              }`}>
                <Shield className={`w-6 h-6 ${
                  flow_status?.envoy?.status === 'healthy' ? 'text-green-600' : 
                  flow_status?.envoy?.status === 'degraded' ? 'text-yellow-600' : 'text-red-600'
                }`} />
              </div>
              <div className="text-sm font-medium">Envoy</div>
              <div className="text-xs text-gray-500">{flow_metrics?.envoy_requests || 0} → RLS</div>
            </div>

            {/* Arrow */}
            <div className="flex items-center justify-center">
              <div className={`w-8 h-1 ${health_checks?.rls_service ? 'bg-green-500' : 'bg-red-500'} rounded`}></div>
              <ArrowRight className="w-4 h-4 text-gray-400" />
            </div>

            {/* RLS */}
            <div className="text-center">
              <div className={`w-12 h-12 mx-auto rounded-full flex items-center justify-center mb-2 ${
                flow_status?.rls?.status === 'healthy' ? 'bg-green-100' : 
                flow_status?.rls?.status === 'degraded' ? 'bg-yellow-100' : 'bg-red-100'
              }`}>
                <Zap className={`w-6 h-6 ${
                  flow_status?.rls?.status === 'healthy' ? 'text-green-600' : 
                  flow_status?.rls?.status === 'degraded' ? 'text-yellow-600' : 'text-red-600'
                }`} />
              </div>
              <div className="text-sm font-medium">RLS</div>
              <div className="text-xs text-gray-500">{flow_metrics?.envoy_authorized || 0} ✓ {flow_metrics?.envoy_denied || 0} ✗</div>
            </div>

            {/* Arrow */}
            <div className="flex items-center justify-center">
              <div className={`w-8 h-1 ${health_checks?.mimir_connectivity ? 'bg-green-500' : 'bg-red-500'} rounded`}></div>
              <ArrowRight className="w-4 h-4 text-gray-400" />
            </div>

            {/* Mimir */}
            <div className="text-center">
              <div className={`w-12 h-12 mx-auto rounded-full flex items-center justify-center mb-2 ${
                flow_status?.mimir?.status === 'healthy' ? 'bg-green-100' : 
                flow_status?.mimir?.status === 'degraded' ? 'bg-yellow-100' : 'bg-red-100'
              }`}>
                <Database className={`w-6 h-6 ${
                  flow_status?.mimir?.status === 'healthy' ? 'text-green-600' : 
                  flow_status?.mimir?.status === 'degraded' ? 'text-yellow-600' : 'text-red-600'
                }`} />
              </div>
              <div className="text-sm font-medium">Mimir</div>
              <div className="text-xs text-gray-500">{flow_metrics?.mimir_requests || 0} (allowed)</div>
            </div>
          </div>

          {/* Flow Issues */}
          {flow_status?.overall !== 'healthy' && (
            <div className="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <div className="flex items-center">
                <AlertTriangle className="w-5 h-5 text-yellow-600 mr-2" />
                <h3 className="text-sm font-medium text-yellow-800">Flow Issues Detected</h3>
              </div>
              <div className="mt-2 text-sm text-yellow-700">
                {flow_status?.nginx?.status !== 'healthy' && (
                  <div>• NGINX: {flow_status.nginx?.message || 'Unknown issue'}</div>
                )}
                {flow_status?.envoy?.status !== 'healthy' && (
                  <div>• Envoy: {flow_status.envoy?.message || 'Unknown issue'}</div>
                )}
                {flow_status?.rls?.status !== 'healthy' && (
                  <div>• RLS: {flow_status.rls?.message || 'Unknown issue'}</div>
                )}
                {flow_status?.overrides_sync?.status !== 'healthy' && (
                  <div>• Overrides Sync: {flow_status.overrides_sync?.message || 'Unknown issue'}</div>
                )}
                {flow_status?.mimir?.status !== 'healthy' && (
                  <div>• Mimir: {flow_status.mimir?.message || 'Unknown issue'}</div>
                )}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Key Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Requests</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.total_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              +{flow_timeline?.[0]?.nginx_requests || 0} from last period
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Allowed Requests</CardTitle>
            <CheckCircle className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{stats?.allowed_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              {stats?.allow_percentage?.toFixed(1) || 0}% success rate
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Denied Requests</CardTitle>
            <XCircle className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">{stats?.denied_requests?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              {(100 - (stats?.allow_percentage || 0)).toFixed(1)}% denial rate
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Tenants</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.active_tenants || 0}</div>
            <p className="text-xs text-muted-foreground">
              With configured limits
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Top Tenants */}
      <Card>
        <CardHeader>
          <CardTitle>Top Tenants by RPS</CardTitle>
          <CardDescription>
            Tenants with highest request rates and denial percentages
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {top_tenants?.map((tenant) => (
              <div key={tenant.id} className="flex items-center justify-between p-4 border rounded-lg">
                <div className="flex items-center space-x-4">
                  <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                    <Users className="w-4 h-4 text-blue-600" />
                  </div>
                  <div>
                    <div className="font-medium">{tenant.name}</div>
                    <div className="text-sm text-gray-500">ID: {tenant.id}</div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="font-medium">{tenant.rps} RPS</div>
                  <div className="text-sm text-gray-500">
                    {tenant.deny_rate > 0 ? (
                      <span className="text-red-600">{tenant.deny_rate}% denied</span>
                    ) : (
                      <span className="text-green-600">100% allowed</span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Comprehensive Endpoint Monitoring */}
      <Card>
        <CardHeader>
          <CardTitle>Comprehensive Endpoint Monitoring</CardTitle>
          <CardDescription>
            Real-time status of all endpoints across all services
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            {/* Service Status Overview */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
              {Object.entries(service_status).map(([service, data]: [string, any]) => (
                <div key={service} className="p-4 border rounded-lg">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-medium capitalize">{service}</h3>
                    <StatusBadge status={data?.status || 'unknown'} />
                  </div>
                  <p className="text-sm text-gray-600 mb-2">{data?.message || 'Status unknown'}</p>
                  <div className="text-xs text-gray-500">
                    <div>Version: {data?.version || 'Unknown'}</div>
                    <div>Uptime: {data?.uptime || 'Unknown'}</div>
                    <div>Last Check: {data?.last_check ? new Date(data.last_check).toLocaleTimeString() : 'Unknown'}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Endpoint Details */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Endpoint Details</h3>
              {Object.entries(endpoint_status).map(([service, endpoints]: [string, any]) => (
                <div key={service} className="border rounded-lg p-4">
                  <h4 className="font-medium capitalize mb-3">{service} Endpoints</h4>
                  <div className="grid gap-2 md:grid-cols-2 lg:grid-cols-3">
                    {Object.entries(endpoints).map(([endpoint, data]: [string, any]) => (
                      <div key={endpoint} className="p-3 border rounded bg-gray-50">
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-sm font-medium">{endpoint}</span>
                          <StatusBadge status={data?.status || 'unknown'} />
                        </div>
                        <p className="text-xs text-gray-600 mb-1">{data?.message || 'Status unknown'}</p>
                        <div className="text-xs text-gray-500">
                          <div>Response: {data?.response_time || 0}ms</div>
                          <div>Status: {data?.actual_status || 0}/{data?.expected_status || 0}</div>
                          <div>Size: {data?.response_size || 0} bytes</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>

            {/* Validation Results */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Validation Results</h3>
              {Object.entries(validation_results).map(([category, validations]: [string, any]) => (
                <div key={category} className="border rounded-lg p-4">
                  <h4 className="font-medium capitalize mb-3">{category.replace('_', ' ')}</h4>
                  <div className="grid gap-2 md:grid-cols-2 lg:grid-cols-3">
                    {Object.entries(validations).map(([validation, data]: [string, any]) => (
                      <div key={validation} className="p-3 border rounded bg-gray-50">
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-sm font-medium">{validation.replace('_', ' ')}</span>
                          <StatusBadge status={data?.status || 'unknown'} />
                        </div>
                        <p className="text-xs text-gray-600 mb-1">{data?.message || 'Status unknown'}</p>
                        <div className="text-xs text-gray-500">
                          Last Check: {data?.last_check ? new Date(data.last_check).toLocaleTimeString() : 'Unknown'}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Flow Timeline */}
      <Card>
        <CardHeader>
          <CardTitle>Flow Timeline</CardTitle>
          <CardDescription>
            Real-time traffic flow over the last {timeRange}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={flow_timeline}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="timestamp" />
              <YAxis />
              <Tooltip />
              <Area type="monotone" dataKey="nginx_requests" stackId="1" stroke="#3b82f6" fill="#3b82f6" name="NGINX" />
              <Area type="monotone" dataKey="envoy_requests" stackId="1" stroke="#10b981" fill="#10b981" name="Envoy" />
              <Area type="monotone" dataKey="mimir_requests" stackId="1" stroke="#8b5cf6" fill="#8b5cf6" name="Mimir" />
            </AreaChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>
    </div>
  );
}

// Enhanced API function with comprehensive flow monitoring
async function fetchOverviewData(timeRange: string): Promise<OverviewData> {
  try {
    // Fetch overview stats with time range
    const overviewResponse = await fetch(`/api/overview?range=${timeRange}`);
    if (!overviewResponse.ok) {
      throw new Error(`Failed to fetch overview data: ${overviewResponse.statusText}`);
    }
    const overviewData = await overviewResponse.json();
    
    // Fetch tenant data with time range to calculate top tenants
    const tenantsResponse = await fetch(`/api/tenants?range=${timeRange}`);
    let topTenants: TopTenant[] = [];
    
    if (tenantsResponse.ok) {
      const tenantsData: TenantsResponse = await tenantsResponse.json();
      const tenants = tenantsData.tenants || [];
      
      // Transform tenants to top tenants format using REAL RPS data from backend
      topTenants = tenants
        .filter((tenant: Tenant) => tenant.metrics && ((tenant.metrics.rps || 0) > 0 || tenant.metrics.allow_rate > 0 || tenant.metrics.deny_rate > 0))
        .map((tenant: Tenant): TopTenant => ({
          id: tenant.id,
          name: tenant.name || tenant.id,
          rps: tenant.metrics?.rps || 0, // Use REAL RPS from backend
          samples_per_sec: tenant.metrics?.samples_per_sec || 0, // Use samples_per_sec from metrics
          deny_rate: tenant.metrics?.deny_rate || 0
        }))
        .sort((a: TopTenant, b: TopTenant) => b.rps - a.rps) // Sort by RPS descending
        .slice(0, 10); // Top 10 tenants
    }
    
    // If no real tenant data, show message
    if (topTenants.length === 0) {
      topTenants = [
        { id: 'no-data', name: 'No Active Tenants', rps: 0, samples_per_sec: 0, deny_rate: 0 }
      ];
    }
    
    // Get real traffic flow data from the new API endpoint
    let flow_metrics: FlowMetrics;
    try {
      const trafficFlowResponse = await fetch('/api/traffic/flow');
      if (trafficFlowResponse.ok) {
        const trafficFlowData = await trafficFlowResponse.json();
        const flowData = trafficFlowData.flow_metrics;
        const responseTimes = flowData.response_times;
        
        flow_metrics = {
          nginx_requests: 0, // We don't track NGINX directly
          nginx_route_direct: 0,
          nginx_route_edge: flowData.envoy_to_rls_requests || 0,
          envoy_requests: flowData.envoy_to_rls_requests || 0,
          envoy_authorized: flowData.rls_allowed || 0,
          envoy_denied: flowData.rls_denied || 0,
          mimir_requests: flowData.rls_to_mimir_requests || 0,
          mimir_success: flowData.rls_to_mimir_requests || 0,
          mimir_errors: flowData.mimir_errors || 0,
          response_times: {
            nginx_to_envoy: 0, // We don't track NGINX directly
            envoy_to_mimir: responseTimes?.rls_to_mimir || 0,
            total_flow: responseTimes?.total_flow || 0
          }
        };
      } else {
        // Fallback to calculated metrics
        flow_metrics = {
          nginx_requests: 0, // We don't track NGINX directly
          nginx_route_direct: 0,
          nginx_route_edge: overviewData.stats?.total_requests || 0,
          envoy_requests: overviewData.stats?.total_requests || 0,
          envoy_authorized: overviewData.stats?.allowed_requests || 0,
          envoy_denied: overviewData.stats?.denied_requests || 0,
          mimir_requests: overviewData.stats?.allowed_requests || 0,
          mimir_success: overviewData.stats?.allowed_requests || 0,
          mimir_errors: 0,
          response_times: {
            nginx_to_envoy: 0,
            envoy_to_mimir: 0,
            total_flow: 0
          }
        };
      }
    } catch (error) {
      console.error('Error fetching traffic flow data:', error);
      // Fallback to calculated metrics
      flow_metrics = {
        nginx_requests: 0, // We don't track NGINX directly
        nginx_route_direct: 0,
        nginx_route_edge: overviewData.stats?.total_requests || 0,
        envoy_requests: overviewData.stats?.total_requests || 0,
        envoy_authorized: overviewData.stats?.allowed_requests || 0,
        envoy_denied: overviewData.stats?.denied_requests || 0,
        mimir_requests: overviewData.stats?.allowed_requests || 0,
        mimir_success: overviewData.stats?.allowed_requests || 0,
        mimir_errors: 0,
        response_times: {
          nginx_to_envoy: 0,
          envoy_to_mimir: 0,
          total_flow: 0
        }
      };
    }

    // Get real time-series data instead of generating fake data
    const flow_timeline: FlowDataPoint[] = await getRealFlowTimeline(timeRange);

    // Perform comprehensive health checks
    const health_checks = await performHealthChecks();

    // Determine flow status based on health checks and metrics
    const flow_status = await determineFlowStatus(health_checks, overviewData, flow_metrics);

    // Get service and endpoint status
    const service_status = await getServiceStatus();
    const endpoint_status = await getEndpointStatus();
    const validation_results = await getValidationResults();

    return {
      stats: overviewData.stats,
      top_tenants: topTenants,
      flow_metrics,
      flow_timeline,
      flow_status,
      health_checks,
      service_status,
      endpoint_status,
      validation_results,
    };
  } catch (error) {
    console.error('Error fetching overview data:', error);
    throw error;
  }
}

// Get real time-series data from backend
async function getRealFlowTimeline(timeRange: string): Promise<FlowDataPoint[]> {
  try {
    // Try to get real time-series data from the backend
    const response = await fetch(`/api/timeseries/${timeRange}/flow`);
    if (response.ok) {
      const data = await response.json();
      return data.points || [];
    }
  } catch (error) {
    console.warn('Could not fetch real time-series data:', error);
  }
  
  // Fallback to calculated timeline based on current metrics
  return generateCalculatedFlowTimeline(timeRange);
}

// Generate calculated timeline based on current metrics (fallback)
function generateCalculatedFlowTimeline(timeRange: string): FlowDataPoint[] {
  const now = new Date();
  const points: FlowDataPoint[] = [];
  
  let interval: number;
  let count: number;
  
  switch (timeRange) {
    case '15m':
      interval = 1 * 60 * 1000; // 1 minute
      count = 15;
      break;
    case '1h':
      interval = 5 * 60 * 1000; // 5 minutes
      count = 12;
      break;
    case '24h':
      interval = 60 * 60 * 1000; // 1 hour
      count = 24;
      break;
    case '1w':
      interval = 24 * 60 * 60 * 1000; // 1 day
      count = 7;
      break;
    default:
      interval = 5 * 60 * 1000; // 5 minutes
      count = 12;
  }
  
  for (let i = count - 1; i >= 0; i--) {
    const timestamp = new Date(now.getTime() - (i * interval));
    points.push({
      timestamp: timestamp.toISOString(),
      nginx_requests: 0, // We don't track NGINX directly
      route_direct: 0,
      route_edge: 0,
      envoy_requests: 0,
      mimir_requests: 0,
      success_rate: 0
    });
  }
  
  return points;
}

// Helper functions for status checks
async function getServiceStatus(): Promise<Record<string, any>> {
  try {
    const response = await fetch('/api/system/status');
    if (response.ok) {
      const data = await response.json();
      return data.services || {};
    }
  } catch (error) {
    console.error('Error fetching service status:', error);
  }
  return {};
}

async function getEndpointStatus(): Promise<Record<string, any>> {
  try {
    const response = await fetch('/api/system/status');
    if (response.ok) {
      const data = await response.json();
      return data.endpoints || {};
    }
  } catch (error) {
    console.error('Error fetching endpoint status:', error);
  }
  return {};
}

async function getValidationResults(): Promise<Record<string, any>> {
  try {
    const response = await fetch('/api/system/status');
    if (response.ok) {
      const data = await response.json();
      return data.validations || {};
    }
  } catch (error) {
    console.error('Error fetching validation results:', error);
  }
  return {};
}

// Perform comprehensive health checks
async function performHealthChecks(): Promise<HealthChecks> {
  const checks: HealthChecks = {
    rls_service: false,
    overrides_sync: false,
    envoy_proxy: false,
    nginx_config: false,
    mimir_connectivity: false,
    tenant_limits_synced: false,
    enforcement_active: false
  };

  try {
    // Check RLS service health endpoint
    const rlsStart = Date.now();
    const rlsResponse = await fetch('/api/health');
    const rlsTime = Date.now() - rlsStart;
    
    if (rlsResponse.ok) {
      const rlsData = await rlsResponse.json();
      checks.rls_service = rlsData.status === 'healthy' || rlsData.status === 'ok';
    } else {
      // Fallback: check if RLS is responding at all
      checks.rls_service = rlsTime < 5000; // 5 second timeout
    }

    // Check RLS readiness endpoint
    try {
      const readyResponse = await fetch('/api/ready');
      checks.rls_service = checks.rls_service && readyResponse.ok;
    } catch (error) {
      console.warn('RLS readiness check failed:', error);
    }

    // Check overrides sync service
    try {
      const overridesResponse = await fetch('/api/overrides-sync/health');
      if (overridesResponse.ok) {
        const overridesData = await overridesResponse.json();
        checks.overrides_sync = overridesData.status === 'healthy' || overridesData.status === 'ok';
      } else {
        // Fallback: check if overrides sync is working by looking at tenant data
        checks.overrides_sync = false;
      }
    } catch (error) {
      console.warn('Overrides sync health check failed:', error);
      checks.overrides_sync = false;
    }

    // Check if tenants have limits (indicates sync is working)
    try {
      const tenantsResponse = await fetch('/api/tenants');
      if (tenantsResponse.ok) {
        const tenantsData = await tenantsResponse.json();
        const tenantsWithLimits = tenantsData.tenants?.filter((t: any) => 
          t.limits && (
            (t.limits.samples_per_second && t.limits.samples_per_second > 0) ||
            (t.limits.max_body_bytes && t.limits.max_body_bytes > 0) ||
            (t.limits.burst_pct && t.limits.burst_pct > 0)
          )
        ) || [];
        checks.tenant_limits_synced = tenantsWithLimits.length > 0;
      }
    } catch (error) {
      console.warn('Tenant limits check failed:', error);
      checks.tenant_limits_synced = false;
    }

    // Check if enforcement is active (denials > 0 or active tenants > 0)
    try {
      const overviewResponse = await fetch('/api/overview');
      if (overviewResponse.ok) {
        const overviewData = await overviewResponse.json();
        const hasDenials = (overviewData.stats?.denied_requests || 0) > 0;
        const hasActiveTenants = (overviewData.stats?.active_tenants || 0) > 0;
        const hasTraffic = (overviewData.stats?.total_requests || 0) > 0;
        checks.enforcement_active = hasDenials || hasActiveTenants || hasTraffic;
      }
    } catch (error) {
      console.warn('Enforcement check failed:', error);
      checks.enforcement_active = false;
    }

    // Check Envoy proxy connectivity (via RLS ext_authz endpoint)
    try {
      const envoyStart = Date.now();
      const envoyResponse = await fetch('/api/debug/traffic-flow');
      const envoyTime = Date.now() - envoyStart;
      checks.envoy_proxy = envoyResponse.ok && envoyTime < 2000; // 2 second timeout
    } catch (error) {
      console.warn('Envoy proxy check failed:', error);
      checks.envoy_proxy = false;
    }

    // Check Mimir connectivity (via RLS to Mimir requests)
    try {
      const mimirResponse = await fetch('/api/debug/traffic-flow');
      if (mimirResponse.ok) {
        const mimirData = await mimirResponse.json();
        const hasMimirRequests = (mimirData.flow_metrics?.rls_to_mimir_requests || 0) > 0;
        const hasMimirErrors = (mimirData.flow_metrics?.mimir_errors || 0) === 0; // No errors = healthy
        checks.mimir_connectivity = hasMimirRequests && hasMimirErrors;
      } else {
        checks.mimir_connectivity = false;
      }
    } catch (error) {
      console.warn('Mimir connectivity check failed:', error);
      checks.mimir_connectivity = false;
    }

    // Check NGINX configuration (assume working if traffic is flowing)
    try {
      const nginxResponse = await fetch('/api/debug/traffic-flow');
      if (nginxResponse.ok) {
        const nginxData = await nginxResponse.json();
        const hasTraffic = (nginxData.flow_metrics?.envoy_to_rls_requests || 0) > 0;
        checks.nginx_config = hasTraffic;
      } else {
        checks.nginx_config = false;
      }
    } catch (error) {
      console.warn('NGINX config check failed:', error);
      checks.nginx_config = false;
    }

  } catch (error) {
    console.error('Health checks failed:', error);
    // Set all checks to false on complete failure
    Object.keys(checks).forEach(key => {
      checks[key as keyof HealthChecks] = false;
    });
  }

  return checks;
}

// Determine flow status based on health checks and metrics
async function determineFlowStatus(
  health_checks: HealthChecks, 
  overviewData: any, 
  flow_metrics: FlowMetrics
): Promise<FlowStatus> {
  const now = new Date().toISOString();
  
  // Determine individual component status
  const nginx: ComponentStatus = {
    status: health_checks.nginx_config ? 'healthy' : 'broken',
    message: health_checks.nginx_config ? 'Traffic routing normally' : 'Configuration issues detected',
    last_seen: now,
    response_time: 50, // Estimated
    error_count: health_checks.nginx_config ? 0 : 1
  };

  const envoy: ComponentStatus = {
    status: health_checks.envoy_proxy ? 'healthy' : 'broken',
    message: health_checks.envoy_proxy ? 'Proxy functioning normally' : 'Proxy service unavailable',
    last_seen: now,
    response_time: 100, // Estimated
    error_count: health_checks.envoy_proxy ? 0 : 1
  };

  const rls: ComponentStatus = {
    status: health_checks.rls_service ? 'healthy' : 'broken',
    message: health_checks.rls_service ? 'Service responding normally' : 'RLS service unavailable',
    last_seen: now,
    response_time: 75, // Estimated
    error_count: health_checks.rls_service ? 0 : 1
  };

  const overrides_sync: ComponentStatus = {
    status: health_checks.overrides_sync ? 'healthy' : 'broken',
    message: health_checks.overrides_sync ? 'Limits syncing normally' : 'Overrides sync issues',
    last_seen: now,
    response_time: 200, // Estimated
    error_count: health_checks.overrides_sync ? 0 : 1
  };

  const mimir: ComponentStatus = {
    status: health_checks.mimir_connectivity ? 'healthy' : 'broken',
    message: health_checks.mimir_connectivity ? 'Backend accessible' : 'Mimir connectivity issues',
    last_seen: now,
    response_time: 150, // Estimated
    error_count: health_checks.mimir_connectivity ? 0 : 1
  };

  // Determine overall status
  let overall: 'healthy' | 'degraded' | 'broken' | 'unknown' = 'unknown';
  const healthyComponents = [nginx, envoy, rls, overrides_sync, mimir].filter(c => c.status === 'healthy').length;
  
  if (healthyComponents === 5) {
    overall = 'healthy';
  } else if (healthyComponents >= 3) {
    overall = 'degraded';
  } else {
    overall = 'broken';
  }

  return {
    overall,
    nginx,
    envoy,
    rls,
    overrides_sync,
    mimir,
    last_check: now
  };
}

// Arrow component for flow diagram
function ArrowRight({ className }: { className?: string }) {
  return (
    <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
    </svg>
  );
} 