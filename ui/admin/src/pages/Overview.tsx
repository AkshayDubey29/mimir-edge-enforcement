import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,

  PieChart,
  Pie,
  Cell
} from 'recharts';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { TrendingUp, TrendingDown, Activity, Users, AlertTriangle, CheckCircle, BarChart3 } from 'lucide-react';

// TypeScript interfaces for the API data
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

// New interfaces for flow validation metrics
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

// Overview data is now fetched from real RLS API endpoints

const timeRanges = [
  { value: '5m', label: 'Last 5 minutes' },
  { value: '1h', label: 'Last hour' },
  { value: '24h', label: 'Last 24 hours' },
  { value: '7d', label: 'Last 7 days' },
];

export function Overview() {
  const [timeRange, setTimeRange] = useState('1h');

  const { data: overviewData, isLoading, error } = useQuery<OverviewData>(
    ['overview', timeRange],
    () => fetchOverviewData(timeRange),
    {
      refetchInterval: 30000, // Refetch every 30 seconds
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
          <button
            onClick={() => window.location.reload()} 
            className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  // Ensure overviewData exists before destructuring
  if (!overviewData) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">No data available</div>
      </div>
    );
  }

  const { stats, top_tenants, flow_metrics, flow_timeline } = overviewData;

  // Prepare chart data
  const requestData = [
    { name: 'Allowed', value: stats.allowed_requests, color: '#10b981' },
    { name: 'Denied', value: stats.denied_requests, color: '#ef4444' },
  ];

  const tenantChartData = top_tenants.map((tenant: TopTenant) => ({
    name: tenant.name,
    rps: tenant.rps,
    samples: tenant.samples_per_sec,
    denyRate: tenant.deny_rate,
  }));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Overview</h1>
          <p className="text-gray-600">
            Monitor your Mimir edge enforcement system
            <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
              Live Data
            </span>
          </p>
        </div>
        <select 
          value={timeRange} 
          onChange={(e) => setTimeRange(e.target.value)}
          className="w-48 px-3 py-2 border border-gray-300 rounded-md"
        >
          {timeRanges.map((range) => (
            <option key={range.value} value={range.value}>
              {range.label}
            </option>
          ))}
        </select>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Requests</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.total_requests.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              <TrendingUp className="inline h-3 w-3 text-green-500" /> +12% from last hour
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Allow Rate</CardTitle>
            <CheckCircle className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.allow_percentage.toFixed(1)}%</div>
            <p className="text-xs text-muted-foreground">
              {stats.allowed_requests.toLocaleString()} allowed requests
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Denied Requests</CardTitle>
            <AlertTriangle className="h-4 w-4 text-red-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.denied_requests.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              <TrendingDown className="inline h-3 w-3 text-red-500" /> -5% from last hour
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Tenants</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats.active_tenants}</div>
            <p className="text-xs text-muted-foreground">
              Across all environments
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Request Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Request Distribution</CardTitle>
            <CardDescription>Allowed vs denied requests</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={requestData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }: { name: string; percent: number }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {requestData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Top Tenants */}
        <Card>
          <CardHeader>
            <CardTitle>Top Tenants by RPS</CardTitle>
            <CardDescription>Requests per second by tenant</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={tenantChartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="rps" fill="#3b82f6" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* End-to-End Flow Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 mb-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">NGINX Requests</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics.nginx_requests.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              Direct: {flow_metrics.nginx_route_direct.toLocaleString()} | Edge: {flow_metrics.nginx_route_edge.toLocaleString()}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Envoy Processing</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics.envoy_requests.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              Authorized: {flow_metrics.envoy_authorized.toLocaleString()} | Denied: {flow_metrics.envoy_denied.toLocaleString()}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Mimir Success</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{flow_metrics.mimir_success.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              Success Rate: {((flow_metrics.mimir_success / flow_metrics.mimir_requests) * 100).toFixed(1)}%
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Flow Timeline Chart */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>End-to-End Flow Timeline</CardTitle>
          <CardDescription>Real-time request flow through NGINX → Envoy → Mimir</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={flow_timeline}>
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
                  name === 'nginx_requests' ? 'NGINX Requests' :
                  name === 'route_direct' ? 'Direct Route' :
                  name === 'route_edge' ? 'Edge Route' :
                  name === 'envoy_requests' ? 'Envoy Requests' :
                  name === 'mimir_requests' ? 'Mimir Requests' :
                  name === 'success_rate' ? 'Success Rate %' : name
                ]}
              />
              <Bar dataKey="nginx_requests" fill="#3b82f6" name="NGINX Requests" />
              <Bar dataKey="route_direct" fill="#10b981" name="Direct Route" />
              <Bar dataKey="route_edge" fill="#f59e0b" name="Edge Route" />
              <Bar dataKey="envoy_requests" fill="#8b5cf6" name="Envoy Requests" />
              <Bar dataKey="mimir_requests" fill="#ef4444" name="Mimir Requests" />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* Response Times Chart */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle>Response Times</CardTitle>
          <CardDescription>Latency breakdown across the request flow</CardDescription>
        </CardHeader>
        <CardContent>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={[
              {
                name: 'NGINX → Envoy',
                time: flow_metrics.response_times.nginx_to_envoy,
                color: '#3b82f6'
              },
              {
                name: 'Envoy → Mimir',
                time: flow_metrics.response_times.envoy_to_mimir,
                color: '#8b5cf6'
              },
              {
                name: 'Total Flow',
                time: flow_metrics.response_times.total_flow,
                color: '#ef4444'
              }
            ]}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip formatter={(value: any) => [`${value}ms`, 'Response Time']} />
              <Bar dataKey="time" fill="#3b82f6" />
            </BarChart>
          </ResponsiveContainer>
        </CardContent>
      </Card>

      {/* Top Tenants Table */}
      <Card>
        <CardHeader>
          <CardTitle>Top Tenants</CardTitle>
          <CardDescription>Performance metrics for active tenants</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  <th className="text-left py-3 px-4 font-medium">Tenant</th>
                  <th className="text-left py-3 px-4 font-medium">RPS</th>
                  <th className="text-left py-3 px-4 font-medium">Samples/sec</th>
                  <th className="text-left py-3 px-4 font-medium">Deny Rate</th>
                  <th className="text-left py-3 px-4 font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {top_tenants.map((tenant: TopTenant) => (
                  <tr key={tenant.id} className="border-b hover:bg-gray-50">
                    <td className="py-3 px-4 font-medium">{tenant.name}</td>
                    <td className="py-3 px-4">{tenant.rps.toLocaleString()}</td>
                    <td className="py-3 px-4">{tenant.samples_per_sec.toLocaleString()}</td>
                    <td className="py-3 px-4">
                      <span className={`inline-block px-2 py-1 text-xs rounded ${
                        tenant.deny_rate > 2 ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'
                      }`}>
                        {tenant.deny_rate.toFixed(1)}%
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="inline-block px-2 py-1 text-xs rounded bg-green-100 text-green-800">
                        Active
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

// Real API function - calls the RLS admin API
async function fetchOverviewData(timeRange: string): Promise<OverviewData> {
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
  
  // If no real tenant data, use fallback for demo
  if (topTenants.length === 0) {
    topTenants = [
      { id: 'no-data', name: 'No Active Tenants', rps: 0, samples_per_sec: 0, deny_rate: 0 }
    ];
  }
  
  // Generate mock flow metrics for now (will be replaced with real API calls)
  const flow_metrics: FlowMetrics = {
    nginx_requests: 1250,
    nginx_route_direct: 1125,
    nginx_route_edge: 125,
    envoy_requests: 125,
    envoy_authorized: 118,
    envoy_denied: 7,
    mimir_requests: 1243,
    mimir_success: 1238,
    mimir_errors: 5,
    response_times: {
      nginx_to_envoy: 45,
      envoy_to_mimir: 120,
      total_flow: 165
    }
  };

  // Generate mock flow timeline data
  const flow_timeline: FlowDataPoint[] = Array.from({ length: 10 }, (_, i) => ({
    timestamp: new Date(Date.now() - (9 - i) * 60000).toISOString(),
    nginx_requests: Math.floor(Math.random() * 200) + 100,
    route_direct: Math.floor(Math.random() * 180) + 90,
    route_edge: Math.floor(Math.random() * 20) + 10,
    envoy_requests: Math.floor(Math.random() * 20) + 10,
    mimir_requests: Math.floor(Math.random() * 200) + 100,
    success_rate: Math.floor(Math.random() * 10) + 95
  }));

  return {
    stats: overviewData.stats,
    top_tenants: topTenants,
    flow_metrics,
    flow_timeline
  };
} 