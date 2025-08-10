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
      refetchInterval: 10000, // Refetch every 10 seconds for real-time updates
      refetchIntervalInBackground: true,
      staleTime: 5000, // Consider data stale after 5 seconds
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
          <div className="text-lg text-red-600 mb-2">Error loading overview data</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  const { stats, top_tenants, flow_metrics, flow_timeline, flow_status, health_checks, service_status, endpoint_status, validation_results } = overviewData || {
    stats: { total_requests: 0, allowed_requests: 0, denied_requests: 0, allow_percentage: 0, active_tenants: 0 },
    top_tenants: [],
    flow_metrics: { nginx_requests: 0, nginx_route_direct: 0, nginx_route_edge: 0, envoy_requests: 0, envoy_authorized: 0, envoy_denied: 0, mimir_requests: 0, mimir_success: 0, mimir_errors: 0, response_times: { nginx_to_envoy: 0, envoy_to_mimir: 0, total_flow: 0 } },
    flow_timeline: [],
    flow_status: { overall: 'unknown', nginx: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 }, envoy: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 }, rls: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 }, overrides_sync: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 }, mimir: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 }, last_check: '' },
    health_checks: { rls_service: false, overrides_sync: false, envoy_proxy: false, nginx_config: false, mimir_connectivity: false, tenant_limits_synced: false, enforcement_active: false },
    service_status: {},
    endpoint_status: {},
    validation_results: {}
  };

  return (
    <div className="space-y-6">
      {/* Header with overall status */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Edge Enforcement Overview</h1>
          <p className="text-gray-500">Real-time monitoring of the Mimir Edge Enforcement pipeline</p>
        </div>
        <div className="flex items-center space-x-4">
          <StatusBadge status={flow_status?.overall || 'unknown'} />
          <div className="flex items-center space-x-2 text-sm text-gray-500">
            <RefreshCw className="w-4 h-4 animate-spin" />
            <span>Auto-refresh (10s)</span>
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
              <div className="text-xs text-gray-500">{flow_metrics?.envoy_requests || 0} req/s</div>
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
              <div className="text-xs text-gray-500">{stats?.active_tenants || 0} tenants</div>
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
              <div className="text-xs text-gray-500">{flow_metrics?.mimir_requests || 0} req/s</div>
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
    // Fetch overview stats
    const overviewResponse = await fetch(`/api/overview?range=${timeRange}`);
    if (!overviewResponse.ok) {
      throw new Error(`Failed to fetch overview data: ${overviewResponse.statusText}`);
    }
    const overviewData = await overviewResponse.json();
    
    // Fetch tenant data to calculate top tenants
    const tenantsResponse = await fetch('/api/tenants');
    let topTenants: TopTenant[] = [];
    
    if (tenantsResponse.ok) {
      const tenantsData: TenantsResponse = await tenantsResponse.json();
      const tenants = tenantsData.tenants || [];
      
      // Transform tenants to top tenants format and sort by metrics
      topTenants = tenants
        .filter((tenant: Tenant) => tenant.metrics && (tenant.metrics.allow_rate > 0 || tenant.metrics.deny_rate > 0))
        .map((tenant: Tenant): TopTenant => ({
          id: tenant.id,
          name: tenant.name || tenant.id,
          rps: Math.round((tenant.metrics!.allow_rate + tenant.metrics!.deny_rate) / 60), // Convert to RPS estimate
          samples_per_sec: tenant.limits?.samples_per_second || 0,
          deny_rate: tenant.metrics!.deny_rate > 0 
            ? Math.round(((tenant.metrics!.deny_rate / (tenant.metrics!.allow_rate + tenant.metrics!.deny_rate)) * 100) * 10) / 10
            : 0
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
                      nginx_requests: flowData.nginx_requests || 0,
                      nginx_route_direct: flowData.nginx_route_direct || 0,
                      nginx_route_edge: flowData.nginx_route_edge || 0,
                      envoy_requests: flowData.envoy_requests || 0,
                      envoy_authorized: flowData.envoy_authorized || 0,
                      envoy_denied: flowData.envoy_denied || 0,
                      mimir_requests: flowData.mimir_requests || 0,
                      mimir_success: flowData.mimir_success || 0,
                      mimir_errors: flowData.mimir_errors || 0,
                      response_times: {
                        nginx_to_envoy: responseTimes?.nginx_to_envoy || 0,
                        envoy_to_mimir: responseTimes?.envoy_to_mimir || 0,
                        total_flow: responseTimes?.total_flow || 0
                      }
                    };
                  } else {
                    // Fallback to calculated metrics
                    flow_metrics = {
                      nginx_requests: overviewData.stats?.total_requests || 0,
                      nginx_route_direct: 0, // No direct traffic in edge enforcement
                      nginx_route_edge: overviewData.stats?.total_requests || 0, // All traffic goes through edge
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
                    nginx_requests: overviewData.stats?.total_requests || 0,
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

    // Generate flow timeline data based on current stats
    const flow_timeline: FlowDataPoint[] = [
      {
        timestamp: new Date().toISOString(),
        nginx_requests: flow_metrics.nginx_requests,
        route_direct: flow_metrics.nginx_route_direct,
        route_edge: flow_metrics.nginx_route_edge,
        envoy_requests: flow_metrics.envoy_requests,
        mimir_requests: flow_metrics.mimir_requests,
        success_rate: overviewData.stats?.allow_percentage || 0
      }
    ];

    // Get comprehensive system status from backend
    const systemStatusResponse = await fetch('/api/system/status');
    let flow_status: FlowStatus;
    let health_checks: HealthChecks;
    let endpoint_status: any = {};
    let service_status: any = {};
    let validation_results: any = {};
    
    if (systemStatusResponse.ok) {
      const systemStatusData = await systemStatusResponse.json();
      
      // Extract flow_status from the new structure
      const overallHealth = systemStatusData.overall_health || {};
      const services = systemStatusData.services || {};
      
      // Convert the new structure to the expected FlowStatus format
      flow_status = {
        overall: overallHealth.status || 'unknown',
        nginx: {
          status: services.nginx?.status || 'unknown',
          message: services.nginx?.message || 'Status unknown',
          last_seen: services.nginx?.last_check || '',
          response_time: 0,
          error_count: 0
        },
        envoy: {
          status: services.envoy?.status || 'unknown',
          message: services.envoy?.message || 'Status unknown',
          last_seen: services.envoy?.last_check || '',
          response_time: 0,
          error_count: 0
        },
        rls: {
          status: services.rls?.status || 'unknown',
          message: services.rls?.message || 'Status unknown',
          last_seen: services.rls?.last_check || '',
          response_time: 0,
          error_count: 0
        },
        overrides_sync: {
          status: services.overrides_sync?.status || 'unknown',
          message: services.overrides_sync?.message || 'Status unknown',
          last_seen: services.overrides_sync?.last_check || '',
          response_time: 0,
          error_count: 0
        },
        mimir: {
          status: services.mimir?.status || 'unknown',
          message: services.mimir?.message || 'Status unknown',
          last_seen: services.mimir?.last_check || '',
          response_time: 0,
          error_count: 0
        },
        last_check: overallHealth.last_check || new Date().toISOString()
      };
      
      // Convert health_checks from the new structure
      health_checks = {
        rls_service: services.rls?.status === 'healthy',
        overrides_sync: services.overrides_sync?.status === 'healthy',
        envoy_proxy: services.envoy?.status === 'healthy',
        nginx_config: services.nginx?.status === 'healthy',
        mimir_connectivity: services.mimir?.status === 'healthy',
        tenant_limits_synced: services.overrides_sync?.status === 'healthy',
        enforcement_active: overallHealth.health_percentage > 80
      };
      
      endpoint_status = systemStatusData.endpoints || {};
      service_status = systemStatusData.services || {};
      validation_results = systemStatusData.validations || {};
    } else {
      // Fallback to basic status if API fails
      flow_status = {
        overall: 'unknown',
        nginx: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 },
        envoy: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 },
        rls: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 },
        overrides_sync: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 },
        mimir: { status: 'unknown', message: 'Status unknown', last_seen: '', response_time: 0, error_count: 0 },
        last_check: new Date().toISOString()
      };
      health_checks = {
        rls_service: false,
        overrides_sync: false,
        envoy_proxy: false,
        nginx_config: false,
        mimir_connectivity: false,
        tenant_limits_synced: false,
        enforcement_active: false
      };
    }

    return {
      stats: overviewData.stats,
      top_tenants: topTenants,
      flow_metrics,
      flow_timeline,
      flow_status,
      health_checks,
      service_status,
      endpoint_status,
      validation_results
    };
  } catch (error) {
    console.error('Error fetching overview data:', error);
    // Return empty data structure on error
    return {
      stats: {
        total_requests: 0,
        allowed_requests: 0,
        denied_requests: 0,
        allow_percentage: 0,
        active_tenants: 0
      },
      top_tenants: [],
      flow_metrics: {
        nginx_requests: 0,
        nginx_route_direct: 0,
        nginx_route_edge: 0,
        envoy_requests: 0,
        envoy_authorized: 0,
        envoy_denied: 0,
        mimir_requests: 0,
        mimir_success: 0,
        mimir_errors: 0,
        response_times: {
          nginx_to_envoy: 0,
          envoy_to_mimir: 0,
          total_flow: 0
        }
      },
      flow_timeline: [],
      flow_status: {
        overall: 'broken',
        nginx: { status: 'broken', message: 'Service unavailable', last_seen: '', response_time: 0, error_count: 1 },
        envoy: { status: 'broken', message: 'Service unavailable', last_seen: '', response_time: 0, error_count: 1 },
        rls: { status: 'broken', message: 'Service unavailable', last_seen: '', response_time: 0, error_count: 1 },
        overrides_sync: { status: 'broken', message: 'Service unavailable', last_seen: '', response_time: 0, error_count: 1 },
        mimir: { status: 'broken', message: 'Service unavailable', last_seen: '', response_time: 0, error_count: 1 },
        last_check: new Date().toISOString()
      },
      health_checks: {
        rls_service: false,
        overrides_sync: false,
        envoy_proxy: false,
        nginx_config: false,
        mimir_connectivity: false,
        tenant_limits_synced: false,
        enforcement_active: false
      },
      service_status: {},
      endpoint_status: {},
      validation_results: {}
    };
  }
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
    // Check RLS service
    const rlsStart = Date.now();
    const rlsResponse = await fetch('/api/health');
    const rlsTime = Date.now() - rlsStart;
    checks.rls_service = rlsResponse.ok && rlsTime < 1000;

    // Check overrides sync (via pipeline status)
    const pipelineResponse = await fetch('/api/pipeline/status');
    if (pipelineResponse.ok) {
      const pipelineData = await pipelineResponse.json();
      checks.overrides_sync = pipelineData.components?.overrides_sync?.status === 'healthy';
    }

    // Check if tenants have limits (indicates sync is working)
    const tenantsResponse = await fetch('/api/tenants');
    if (tenantsResponse.ok) {
      const tenantsData = await tenantsResponse.json();
      const tenantsWithLimits = tenantsData.tenants?.filter((t: any) => 
        t.limits && Object.values(t.limits).some((v: any) => v > 0)
      ) || [];
      checks.tenant_limits_synced = tenantsWithLimits.length > 0;
    }

    // Check if enforcement is active (denials > 0 or active tenants > 0)
    const overviewResponse = await fetch('/api/overview');
    if (overviewResponse.ok) {
      const overviewData = await overviewResponse.json();
      checks.enforcement_active = (overviewData.stats?.denied_requests || 0) > 0 || 
                                  (overviewData.stats?.active_tenants || 0) > 0;
    }

    // For now, assume these are working if RLS is working
    checks.envoy_proxy = checks.rls_service;
    checks.nginx_config = checks.rls_service;
    checks.mimir_connectivity = checks.rls_service;

  } catch (error) {
    console.error('Health checks failed:', error);
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