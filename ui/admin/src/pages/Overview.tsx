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
  StopCircle,
  BarChart3,
  Target,
  Gauge,
  FileText,
  Hash,
  Tag,
  Cpu,
  HardDrive,
  Timer,
  Filter,
  Settings,
  Eye,
  EyeOff,
  RotateCcw,
  Globe,
  Lock,
  Unlock,
  ArrowRight,
  ArrowLeft,
  ArrowUp,
  ArrowDown,
  Minus,
  Plus,
  Circle,
  Square,
  Triangle
} from 'lucide-react';

// Enhanced interfaces for comprehensive system monitoring
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
  utilization_pct: number;
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
  selective_filtering: {
    enabled: boolean;
    filtered_requests: number;
    filtering_percentage: number;
    fallback_to_deny: number;
  };
  cardinality_monitoring: {
    enabled: boolean;
    violations_detected: number;
    series_count: number;
    metrics_count: number;
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
  selective_filtering_rate: number;
  cardinality_violations: number;
}

interface FlowStatus {
  nginx: 'healthy' | 'warning' | 'error';
  envoy: 'healthy' | 'warning' | 'error';
  rls: 'healthy' | 'warning' | 'error';
  mimir: 'healthy' | 'warning' | 'error';
  overrides_sync: 'healthy' | 'warning' | 'error';
}

interface HealthChecks {
  nginx_ready: boolean;
  nginx_live: boolean;
  envoy_ready: boolean;
  envoy_live: boolean;
  rls_ready: boolean;
  rls_live: boolean;
  mimir_ready: boolean;
  mimir_live: boolean;
  overrides_sync_ready: boolean;
  overrides_sync_live: boolean;
}

interface SystemMetrics {
  cpu_usage: number;
  memory_usage: number;
  disk_usage: number;
  network_throughput: number;
  active_connections: number;
  error_rate: number;
  response_time_p95: number;
  response_time_p99: number;
}

interface OverviewData {
  stats: OverviewStats;
  top_tenants: TopTenant[];
  flow_metrics: FlowMetrics;
  flow_timeline: FlowDataPoint[];
  flow_status: FlowStatus;
  health_checks: HealthChecks;
  system_metrics: SystemMetrics;
  service_status: Record<string, any>;
  endpoint_status: Record<string, any>;
  validation_results: Record<string, any>;
}

// Utility functions
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function formatSamplesPerSec(samples: number): string {
  if (samples >= 1000000) {
    return (samples / 1000000).toFixed(1) + 'M';
  } else if (samples >= 1000) {
    return (samples / 1000).toFixed(1) + 'K';
  }
  return samples.toFixed(1);
}

function getStatusColor(status: string): string {
  switch (status) {
    case 'healthy': return 'text-green-600 bg-green-100';
    case 'warning': return 'text-yellow-600 bg-yellow-100';
    case 'error': return 'text-red-600 bg-red-100';
    default: return 'text-gray-600 bg-gray-100';
  }
}

function getStatusIcon(status: string) {
    switch (status) {
    case 'healthy': return <CheckCircle className="h-4 w-4" />;
    case 'warning': return <AlertTriangle className="h-4 w-4" />;
    case 'error': return <XCircle className="h-4 w-4" />;
    default: return <Info className="h-4 w-4" />;
  }
}

export function Overview() {
  const [timeRange, setTimeRange] = useState('15m');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(true);

  const { data, isLoading, error, refetch } = useQuery<OverviewData>({ 
    queryKey: ['overview', timeRange], 
    queryFn: () => fetchOverviewData(timeRange),
    refetchInterval: autoRefresh ? 30000 : false,
      refetchIntervalInBackground: true,
    staleTime: 15000,
    cacheTime: 60000
  });

  if (isLoading) return (
      <div className="flex items-center justify-center h-64">
      <div className="text-lg text-gray-600 flex items-center gap-2">
        <RefreshCw className="h-5 w-5 animate-spin" />
        Loading system overview...
      </div>
      </div>
    );

  if (error) return (
      <div className="flex items-center justify-center h-64">
      <div className="text-lg text-red-600 flex items-center gap-2">
        <AlertCircle className="h-5 w-5" />
        Error loading overview: {error instanceof Error ? error.message : 'Unknown error'}
        </div>
      </div>
    );

  const stats = data?.stats;
  const flowMetrics = data?.flow_metrics;
  const flowStatus = data?.flow_status;
  const healthChecks = data?.health_checks;
  const systemMetrics = data?.system_metrics;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">System Overview</h1>
          <p className="text-gray-600 mt-1">
            Comprehensive monitoring of Mimir Edge Enforcement system
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
            onClick={() => setAutoRefresh(!autoRefresh)}
            className={`flex items-center gap-2 px-3 py-2 text-sm rounded-md transition-colors ${
              autoRefresh 
                ? 'bg-green-100 text-green-700 hover:bg-green-200' 
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            {autoRefresh ? <Play className="h-4 w-4" /> : <Pause className="h-4 w-4" />}
            Auto-refresh {autoRefresh ? 'ON' : 'OFF'}
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
      </div>

      {/* Key Metrics Cards */}
      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Total Requests</p>
                  <p className="text-2xl font-bold text-gray-900">{stats?.total_requests?.toLocaleString() || '0'}</p>
                  <p className="text-xs text-gray-500">Last {timeRange}</p>
            </div>
                <Activity className="h-8 w-8 text-blue-500" />
            </div>
          </CardContent>
        </Card>

        <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Success Rate</p>
                  <p className="text-2xl font-bold text-green-600">{stats?.allow_percentage?.toFixed(1) || '0.0'}%</p>
                  <p className="text-xs text-gray-500">{stats?.allowed_requests?.toLocaleString() || '0'} allowed</p>
            </div>
                <CheckCircle className="h-8 w-8 text-green-500" />
            </div>
          </CardContent>
        </Card>

        <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Denied Requests</p>
                  <p className="text-2xl font-bold text-red-600">{stats?.denied_requests?.toLocaleString() || '0'}</p>
                  <p className="text-xs text-gray-500">{stats?.allow_percentage ? (100 - stats.allow_percentage).toFixed(1) : '0.0'}% denied</p>
                </div>
                <XCircle className="h-8 w-8 text-red-500" />
            </div>
          </CardContent>
        </Card>

        <Card>
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600">Active Tenants</p>
                  <p className="text-2xl font-bold text-gray-900">{stats?.active_tenants || '0'}</p>
                  <p className="text-xs text-gray-500">Currently monitored</p>
                </div>
                <Users className="h-8 w-8 text-purple-500" />
            </div>
          </CardContent>
        </Card>
      </div>
      )}

      {/* Traffic Flow Overview */}
      {flowMetrics && (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
              <Network className="h-5 w-5" />
              Traffic Flow Overview
          </CardTitle>
          <CardDescription>
              Real-time monitoring of request flow through the system
          </CardDescription>
        </CardHeader>
        <CardContent>
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* NGINX Layer */}
              <div className="space-y-4">
                <div className="flex items-center gap-2">
                  <Server className="h-5 w-5 text-blue-500" />
                  <h3 className="font-semibold text-gray-900">NGINX Router</h3>
                  <Badge className={getStatusColor(flowStatus?.nginx || 'unknown')}>
                    {getStatusIcon(flowStatus?.nginx || 'unknown')}
                    {flowStatus?.nginx || 'unknown'}
                  </Badge>
            </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Total Requests:</span>
                    <span className="font-medium">{flowMetrics?.nginx_requests?.toLocaleString() || '0'}</span>
            </div>
                  <div className="flex justify-between">
                    <span>Direct Route:</span>
                    <span className="font-medium text-green-600">{flowMetrics?.nginx_route_direct?.toLocaleString() || '0'}</span>
            </div>
                  <div className="flex justify-between">
                    <span>Edge Route:</span>
                    <span className="font-medium text-blue-600">{flowMetrics?.nginx_route_edge?.toLocaleString() || '0'}</span>
          </div>
              </div>
              </div>

              {/* Envoy Layer */}
              <div className="space-y-4">
                <div className="flex items-center gap-2">
                  <Zap className="h-5 w-5 text-purple-500" />
                  <h3 className="font-semibold text-gray-900">Envoy Proxy</h3>
                  <Badge className={getStatusColor(flowStatus?.envoy || 'unknown')}>
                    {getStatusIcon(flowStatus?.envoy || 'unknown')}
                    {flowStatus?.envoy || 'unknown'}
                  </Badge>
              </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Total Requests:</span>
                    <span className="font-medium">{flowMetrics?.envoy_requests?.toLocaleString() || '0'}</span>
              </div>
                  <div className="flex justify-between">
                    <span>Authorized:</span>
                    <span className="font-medium text-green-600">{flowMetrics?.envoy_authorized?.toLocaleString() || '0'}</span>
              </div>
                  <div className="flex justify-between">
                    <span>Denied:</span>
                    <span className="font-medium text-red-600">{flowMetrics?.envoy_denied?.toLocaleString() || '0'}</span>
            </div>
                  {flowMetrics?.selective_filtering?.enabled && (
                    <div className="flex justify-between">
                      <span>Filtered:</span>
                      <span className="font-medium text-orange-600">{flowMetrics?.selective_filtering?.filtered_requests?.toLocaleString() || '0'}</span>
          </div>
                  )}
              </div>
            </div>

              {/* Mimir Layer */}
              <div className="space-y-4">
                <div className="flex items-center gap-2">
                  <Database className="h-5 w-5 text-red-500" />
                  <h3 className="font-semibold text-gray-900">Mimir Distributor</h3>
                  <Badge className={getStatusColor(flowStatus?.mimir || 'unknown')}>
                    {getStatusIcon(flowStatus?.mimir || 'unknown')}
                    {flowStatus?.mimir || 'unknown'}
                  </Badge>
            </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Total Requests:</span>
                    <span className="font-medium">{flowMetrics?.mimir_requests?.toLocaleString() || '0'}</span>
              </div>
                  <div className="flex justify-between">
                    <span>Success:</span>
                    <span className="font-medium text-green-600">{flowMetrics?.mimir_success?.toLocaleString() || '0'}</span>
            </div>
                  <div className="flex justify-between">
                    <span>Errors:</span>
                    <span className="font-medium text-red-600">{flowMetrics?.mimir_errors?.toLocaleString() || '0'}</span>
            </div>
                  {flowMetrics?.cardinality_monitoring?.enabled && (
                    <div className="flex justify-between">
                      <span>Cardinality Violations:</span>
                      <span className="font-medium text-yellow-600">{flowMetrics?.cardinality_monitoring?.violations_detected?.toLocaleString() || '0'}</span>
              </div>
                  )}
            </div>
            </div>
            </div>

            {/* Response Times */}
            <div className="mt-6 pt-6 border-t border-gray-200">
              <h4 className="font-medium text-gray-700 mb-3">Response Times</h4>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center p-3 bg-gray-50 rounded-lg">
                  <div className="text-lg font-semibold text-blue-600">
                    {flowMetrics?.response_times?.nginx_to_envoy ? (flowMetrics.response_times.nginx_to_envoy * 1000).toFixed(1) : '0.0'}ms
            </div>
                  <div className="text-sm text-gray-600">NGINX → Envoy</div>
              </div>
                <div className="text-center p-3 bg-gray-50 rounded-lg">
                  <div className="text-lg font-semibold text-purple-600">
                    {flowMetrics?.response_times?.envoy_to_mimir ? (flowMetrics.response_times.envoy_to_mimir * 1000).toFixed(1) : '0.0'}ms
            </div>
                  <div className="text-sm text-gray-600">Envoy → Mimir</div>
          </div>
                <div className="text-center p-3 bg-gray-50 rounded-lg">
                  <div className="text-lg font-semibold text-green-600">
                    {flowMetrics?.response_times?.total_flow ? (flowMetrics.response_times.total_flow * 1000).toFixed(1) : '0.0'}ms
              </div>
                  <div className="text-sm text-gray-600">Total Flow</div>
              </div>
            </div>
            </div>
        </CardContent>
      </Card>
      )}

      {/* System Health Status */}
      {healthChecks && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5" />
              System Health Status
            </CardTitle>
            <CardDescription>
              Component health and readiness checks
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {Object.entries(healthChecks).map(([service, status]) => {
                const serviceName = service.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                const isReady = service.includes('ready');
                const isLive = service.includes('live');
                
                return (
                  <div key={service} className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                    <div className="flex items-center gap-2">
                      {isReady ? <CheckCircle className="h-4 w-4 text-green-500" /> : <Activity className="h-4 w-4 text-blue-500" />}
                      <span className="font-medium text-gray-700">{serviceName}</span>
      </div>
                    <Badge className={status ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}>
                      {status ? (isReady ? 'Ready' : 'Live') : (isReady ? 'Not Ready' : 'Not Live')}
                    </Badge>
            </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Top Tenants */}
      {data?.top_tenants && data.top_tenants.length > 0 && (
      <Card>
        <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Top Tenants by Activity
            </CardTitle>
          <CardDescription>
              Most active tenants in the last {timeRange}
          </CardDescription>
        </CardHeader>
        <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="text-left py-2 px-4 font-medium text-gray-700">Tenant</th>
                    <th className="text-left py-2 px-4 font-medium text-gray-700">RPS</th>
                    <th className="text-left py-2 px-4 font-medium text-gray-700">Samples/sec</th>
                    <th className="text-left py-2 px-4 font-medium text-gray-700">Deny Rate</th>
                    <th className="text-left py-2 px-4 font-medium text-gray-700">Utilization</th>
                  </tr>
                </thead>
                <tbody>
                  {data.top_tenants.map((tenant, index) => (
                    <tr key={tenant.id} className="border-b border-gray-100">
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium text-gray-900">{tenant.name}</span>
                          <span className="text-xs text-gray-500">({tenant.id})</span>
                  </div>
                      </td>
                      <td className="py-2 px-4">
                        <span className="font-medium">{tenant?.rps?.toFixed(1) || '0.0'}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className="font-medium">{formatSamplesPerSec(tenant?.samples_per_sec || 0)}</span>
                      </td>
                      <td className="py-2 px-4">
                        <span className={`font-medium ${(tenant?.deny_rate || 0) > 0 ? 'text-red-600' : 'text-gray-600'}`}>
                          {(tenant?.deny_rate || 0).toFixed(1)}/s
                        </span>
                      </td>
                      <td className="py-2 px-4">
                        <div className="flex items-center gap-2">
                          <span className="font-medium">{(tenant?.utilization_pct || 0).toFixed(1)}%</span>
                          <div className="w-16 bg-gray-200 rounded-full h-1.5">
                            <div 
                              className={`h-1.5 rounded-full ${
                                (tenant?.utilization_pct || 0) > 90 ? 'bg-red-500' :
                                (tenant?.utilization_pct || 0) > 80 ? 'bg-yellow-500' :
                                (tenant?.utilization_pct || 0) > 60 ? 'bg-blue-500' : 'bg-green-500'
                              }`}
                              style={{ width: `${Math.min(tenant?.utilization_pct || 0, 100)}%` }}
                            />
                  </div>
                </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
          </div>
        </CardContent>
      </Card>
      )}

      {/* Advanced Metrics */}
      {showAdvanced && systemMetrics && (
      <Card>
        <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Settings className="h-5 w-5" />
              System Performance Metrics
            </CardTitle>
          <CardDescription>
              Detailed system resource utilization and performance indicators
          </CardDescription>
        </CardHeader>
        <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="text-center p-4 bg-gray-50 rounded-lg">
                <Cpu className="h-8 w-8 mx-auto mb-2 text-blue-500" />
                <div className="text-lg font-semibold text-gray-900">{(systemMetrics?.cpu_usage || 0).toFixed(1)}%</div>
                <div className="text-sm text-gray-600">CPU Usage</div>
                  </div>
              
              <div className="text-center p-4 bg-gray-50 rounded-lg">
                <HardDrive className="h-8 w-8 mx-auto mb-2 text-green-500" />
                <div className="text-lg font-semibold text-gray-900">{(systemMetrics?.memory_usage || 0).toFixed(1)}%</div>
                <div className="text-sm text-gray-600">Memory Usage</div>
            </div>

              <div className="text-center p-4 bg-gray-50 rounded-lg">
                <Network className="h-8 w-8 mx-auto mb-2 text-purple-500" />
                <div className="text-lg font-semibold text-gray-900">{formatBytes(systemMetrics?.network_throughput || 0)}/s</div>
                <div className="text-sm text-gray-600">Network Throughput</div>
            </div>

              <div className="text-center p-4 bg-gray-50 rounded-lg">
                <Timer className="h-8 w-8 mx-auto mb-2 text-orange-500" />
                <div className="text-lg font-semibold text-gray-900">{(systemMetrics?.response_time_p95 || 0).toFixed(1)}ms</div>
                <div className="text-sm text-gray-600">P95 Response Time</div>
            </div>
          </div>
        </CardContent>
      </Card>
      )}

      {/* Traffic Flow Timeline Chart */}
      {data?.flow_timeline && data.flow_timeline.length > 0 && (
      <Card>
        <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="h-5 w-5" />
              Traffic Flow Timeline
            </CardTitle>
          <CardDescription>
              Request flow patterns over time
          </CardDescription>
        </CardHeader>
        <CardContent>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data.flow_timeline}>
              <CartesianGrid strokeDasharray="3 3" />
                  <XAxis 
                    dataKey="timestamp" 
                    tickFormatter={(value) => new Date(value).toLocaleTimeString()}
                  />
              <YAxis />
                  <Tooltip 
                    labelFormatter={(value) => new Date(value).toLocaleString()}
                    formatter={(value: any, name: string) => [
                      value.toLocaleString(), 
                      name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
                    ]}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="nginx_requests" 
                    stackId="1" 
                    stroke="#3B82F6" 
                    fill="#3B82F6" 
                    fillOpacity={0.6}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="envoy_requests" 
                    stackId="1" 
                    stroke="#8B5CF6" 
                    fill="#8B5CF6" 
                    fillOpacity={0.6}
                  />
                  <Area 
                    type="monotone" 
                    dataKey="mimir_requests" 
                    stackId="1" 
                    stroke="#EF4444" 
                    fill="#EF4444" 
                    fillOpacity={0.6}
                  />
            </AreaChart>
          </ResponsiveContainer>
            </div>
        </CardContent>
      </Card>
      )}
    </div>
  );
}

async function fetchOverviewData(timeRange: string): Promise<OverviewData> {
    const overviewResponse = await fetch(`/api/overview?range=${timeRange}`);
    const tenantsResponse = await fetch(`/api/tenants?range=${timeRange}`);
                  const trafficFlowResponse = await fetch('/api/traffic/flow');
  const systemStatusResponse = await fetch('/api/system/status');
  const systemMetricsResponse = await fetch('/api/metrics/system');

  if (!overviewResponse.ok || !tenantsResponse.ok || !trafficFlowResponse.ok || 
      !systemStatusResponse.ok || !systemMetricsResponse.ok) {
    throw new Error('Failed to fetch overview data');
  }

  const [overview, tenants, trafficFlow, systemStatus, systemMetrics] = await Promise.all([
    overviewResponse.json(),
    tenantsResponse.json(),
    trafficFlowResponse.json(),
    systemStatusResponse.json(),
    systemMetricsResponse.json()
  ]);

    return {
    stats: overview.stats,
    top_tenants: tenants.tenants.slice(0, 10).map((t: any) => ({
      id: t.id,
      name: t.name,
      rps: t.metrics.rps,
      samples_per_sec: t.metrics.samples_per_sec,
      deny_rate: t.metrics.deny_rate,
      utilization_pct: t.metrics.utilization_pct
    })),
    flow_metrics: trafficFlow,
    flow_timeline: await fetchFlowTimeline(timeRange),
    flow_status: systemStatus.flow_status,
    health_checks: systemStatus.health_checks,
    system_metrics: systemMetrics,
    service_status: systemStatus.service_status,
    endpoint_status: systemStatus.endpoint_status,
    validation_results: systemStatus.validation_results
  };
}

async function fetchFlowTimeline(timeRange: string): Promise<FlowDataPoint[]> {
    const response = await fetch(`/api/timeseries/${timeRange}/flow`);
  if (!response.ok) {
    return [];
  }
  return response.json();
} 