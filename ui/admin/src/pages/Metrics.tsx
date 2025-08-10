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
  AreaChart,
  Area,
  PieChart,
  Pie,
  Cell
} from 'recharts';
import { 
  Activity, 
  Clock, 
  AlertTriangle, 
  CheckCircle, 
  XCircle,
  TrendingUp,
  TrendingDown,
  Server,
  Database,
  Network,
  Shield,
  Settings,
  BarChart3,
  Calendar,
  Zap,
  Users,
  Target,
  Gauge
} from 'lucide-react';

// System metrics interface
interface SystemMetrics {
  timestamp: string;
  overview: {
    total_requests_per_second: number;
    total_errors_per_second: number;
    overall_success_rate: number;
    avg_response_time: number;
    active_tenants: number;
    total_denials: number;
    system_health: 'healthy' | 'warning' | 'error';
  };
  component_metrics: {
    nginx: ComponentMetrics;
    envoy: ComponentMetrics;
    rls: ComponentMetrics;
    overrides_sync: ComponentMetrics;
    mimir: ComponentMetrics;
  };
  performance_metrics: {
    cpu_usage: number;
    memory_usage: number;
    disk_usage: number;
    network_throughput: number;
    error_rate: number;
    latency_p95: number;
    latency_p99: number;
  };
  traffic_metrics: {
    requests_per_minute: Array<{ timestamp: string; value: number }>;
    samples_per_minute: Array<{ timestamp: string; value: number }>;
    denials_per_minute: Array<{ timestamp: string; value: number }>;
    response_times: Array<{ timestamp: string; value: number }>;
  };
  tenant_metrics: {
    top_tenants_by_requests: Array<{ tenant_id: string; requests: number; samples: number }>;
    top_tenants_by_denials: Array<{ tenant_id: string; denials: number; deny_rate: number }>;
    utilization_distribution: Array<{ range: string; count: number; percentage: number }>;
  };
  alert_metrics: {
    total_alerts: number;
    critical_alerts: number;
    warning_alerts: number;
    info_alerts: number;
    recent_alerts: Array<{
      id: string;
      severity: 'critical' | 'warning' | 'info';
      message: string;
      timestamp: string;
      component: string;
    }>;
  };
}

interface ComponentMetrics {
  requests_per_second: number;
  error_rate: number;
  response_time: number;
  memory_usage: number;
  cpu_usage: number;
  uptime: string;
  status: 'healthy' | 'warning' | 'error';
}

// Mock data for system metrics
const mockSystemMetrics: SystemMetrics = {
  timestamp: new Date().toISOString(),
  overview: {
    total_requests_per_second: 1250,
    total_errors_per_second: 12,
    overall_success_rate: 99.04,
    avg_response_time: 165,
    active_tenants: 8,
    total_denials: 47,
    system_health: 'healthy'
  },
  component_metrics: {
    nginx: {
      requests_per_second: 1250,
      error_rate: 0.2,
      response_time: 45,
      memory_usage: 85.2,
      cpu_usage: 12.8,
      uptime: '15d 8h 32m',
      status: 'healthy'
    },
    envoy: {
      requests_per_second: 125,
      error_rate: 0.8,
      response_time: 120,
      memory_usage: 92.1,
      cpu_usage: 18.5,
      uptime: '15d 8h 30m',
      status: 'healthy'
    },
    rls: {
      requests_per_second: 125,
      error_rate: 0.1,
      response_time: 25,
      memory_usage: 45.8,
      cpu_usage: 8.2,
      uptime: '15d 8h 28m',
      status: 'healthy'
    },
    overrides_sync: {
      requests_per_second: 0.1,
      error_rate: 0,
      response_time: 150,
      memory_usage: 23.4,
      cpu_usage: 2.1,
      uptime: '15d 8h 25m',
      status: 'healthy'
    },
    mimir: {
      requests_per_second: 1243,
      error_rate: 0.4,
      response_time: 85,
      memory_usage: 78.9,
      cpu_usage: 15.3,
      uptime: '15d 8h 35m',
      status: 'healthy'
    }
  },
  performance_metrics: {
    cpu_usage: 15.2,
    memory_usage: 78.5,
    disk_usage: 45.8,
    network_throughput: 125.5,
    error_rate: 0.96,
    latency_p95: 245,
    latency_p99: 389
  },
  traffic_metrics: {
    requests_per_minute: Array.from({ length: 60 }, (_, i) => ({
      timestamp: new Date(Date.now() - (59 - i) * 60000).toISOString(),
      value: Math.floor(Math.random() * 2000) + 1000
    })),
    samples_per_minute: Array.from({ length: 60 }, (_, i) => ({
      timestamp: new Date(Date.now() - (59 - i) * 60000).toISOString(),
      value: Math.floor(Math.random() * 5000) + 3000
    })),
    denials_per_minute: Array.from({ length: 60 }, (_, i) => ({
      timestamp: new Date(Date.now() - (59 - i) * 60000).toISOString(),
      value: Math.floor(Math.random() * 50) + 10
    })),
    response_times: Array.from({ length: 60 }, (_, i) => ({
      timestamp: new Date(Date.now() - (59 - i) * 60000).toISOString(),
      value: Math.floor(Math.random() * 100) + 100
    }))
  },
  tenant_metrics: {
    top_tenants_by_requests: [
      { tenant_id: 'tenant-1', requests: 450, samples: 1200 },
      { tenant_id: 'tenant-2', requests: 380, samples: 950 },
      { tenant_id: 'tenant-3', requests: 320, samples: 800 },
      { tenant_id: 'tenant-4', requests: 280, samples: 700 },
      { tenant_id: 'tenant-5', requests: 250, samples: 600 }
    ],
    top_tenants_by_denials: [
      { tenant_id: 'tenant-3', denials: 25, deny_rate: 7.8 },
      { tenant_id: 'tenant-1', denials: 18, deny_rate: 4.0 },
      { tenant_id: 'tenant-2', denials: 12, deny_rate: 3.2 },
      { tenant_id: 'tenant-4', denials: 8, deny_rate: 2.9 },
      { tenant_id: 'tenant-5', denials: 5, deny_rate: 2.0 }
    ],
    utilization_distribution: [
      { range: '0-20%', count: 2, percentage: 25 },
      { range: '20-40%', count: 1, percentage: 12.5 },
      { range: '40-60%', count: 2, percentage: 25 },
      { range: '60-80%', count: 2, percentage: 25 },
      { range: '80-100%', count: 1, percentage: 12.5 }
    ]
  },
  alert_metrics: {
    total_alerts: 8,
    critical_alerts: 1,
    warning_alerts: 3,
    info_alerts: 4,
    recent_alerts: [
      {
        id: 'alert-1',
        severity: 'warning',
        message: 'High memory usage detected on Envoy',
        timestamp: '2024-01-15T10:25:00Z',
        component: 'envoy'
      },
      {
        id: 'alert-2',
        severity: 'info',
        message: 'Tenant limits updated successfully',
        timestamp: '2024-01-15T10:20:00Z',
        component: 'overrides-sync'
      },
      {
        id: 'alert-3',
        severity: 'critical',
        message: 'RLS service not responding',
        timestamp: '2024-01-15T10:15:00Z',
        component: 'rls'
      }
    ]
  }
};

// Mock API function
async function fetchSystemMetrics(): Promise<SystemMetrics> {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 500));
  return mockSystemMetrics;
}

// Status badge component
function StatusBadge({ status }: { status: string }) {
  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'healthy':
        return { color: 'bg-green-100 text-green-800', icon: CheckCircle };
      case 'warning':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'error':
        return { color: 'bg-red-100 text-red-800', icon: XCircle };
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: Clock };
    }
  };

  const config = getStatusConfig(status);
  const Icon = config.icon;

  return (
    <Badge className={config.color}>
      <Icon className="w-3 h-3 mr-1" />
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </Badge>
  );
}

export function Metrics() {
  const [timeRange, setTimeRange] = useState('1h');

  const { data: metrics, isLoading, error } = useQuery<SystemMetrics>(
    ['system-metrics', timeRange],
    fetchSystemMetrics,
    {
      refetchInterval: 30000, // Refetch every 30 seconds
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Loading system metrics...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-lg text-red-600 mb-2">Error loading system metrics</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  if (!metrics) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">No metrics data available</div>
      </div>
    );
  }

  // Prepare chart data
  const trafficData = metrics.traffic_metrics.requests_per_minute.map(item => ({
    time: new Date(item.timestamp).toLocaleTimeString(),
    requests: item.value,
    samples: metrics.traffic_metrics.samples_per_minute.find(s => s.timestamp === item.timestamp)?.value || 0,
    denials: metrics.traffic_metrics.denials_per_minute.find(s => s.timestamp === item.timestamp)?.value || 0,
    response_time: metrics.traffic_metrics.response_times.find(s => s.timestamp === item.timestamp)?.value || 0
  }));

  const utilizationPieData = metrics.tenant_metrics.utilization_distribution.map(item => ({
    name: item.range,
    value: item.count,
    percentage: item.percentage
  }));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">System Metrics</h1>
          <p className="text-gray-500">Comprehensive monitoring and performance data</p>
        </div>
        <div className="flex items-center space-x-4">
          <StatusBadge status={metrics.overview.system_health} />
          <div className="text-sm text-gray-500">
            Last updated: {new Date(metrics.timestamp).toLocaleString()}
          </div>
        </div>
      </div>

      {/* System Overview */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total RPS</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.overview.total_requests_per_second.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              {metrics.overview.total_errors_per_second} errors/sec
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.overview.overall_success_rate.toFixed(1)}%</div>
            <p className="text-xs text-muted-foreground">
              {metrics.overview.total_denials} denials today
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.overview.avg_response_time}ms</div>
            <p className="text-xs text-muted-foreground">
              P95: {metrics.performance_metrics.latency_p95}ms
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Tenants</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.overview.active_tenants}</div>
            <p className="text-xs text-muted-foreground">
              With active traffic
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Performance Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">CPU Usage</CardTitle>
            <Gauge className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.performance_metrics.cpu_usage}%</div>
            <p className="text-xs text-muted-foreground">
              System-wide average
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Memory Usage</CardTitle>
            <Database className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.performance_metrics.memory_usage}%</div>
            <p className="text-xs text-muted-foreground">
              System-wide average
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Network Throughput</CardTitle>
            <Network className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.performance_metrics.network_throughput} MB/s</div>
            <p className="text-xs text-muted-foreground">
              Inbound traffic
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Error Rate</CardTitle>
            <XCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.performance_metrics.error_rate}%</div>
            <p className="text-xs text-muted-foreground">
              System-wide average
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Traffic Charts */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Traffic Overview */}
        <Card>
          <CardHeader>
            <CardTitle>Traffic Overview (Last Hour)</CardTitle>
            <CardDescription>Requests, samples, and denials over time</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <AreaChart data={trafficData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Area type="monotone" dataKey="requests" stackId="1" stroke="#3b82f6" fill="#3b82f6" />
                <Area type="monotone" dataKey="samples" stackId="1" stroke="#10b981" fill="#10b981" />
                <Area type="monotone" dataKey="denials" stackId="1" stroke="#ef4444" fill="#ef4444" />
              </AreaChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Response Times */}
        <Card>
          <CardHeader>
            <CardTitle>Response Times (Last Hour)</CardTitle>
            <CardDescription>Average response time trends</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={trafficData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="response_time" stroke="#8b5cf6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Component Metrics */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            Component Performance
          </CardTitle>
          <CardDescription>Detailed metrics for each system component</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {Object.entries(metrics.component_metrics).map(([component, data]) => (
              <div key={component} className="p-4 border rounded-lg">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="font-medium capitalize">{component.replace('_', ' ')}</h3>
                  <StatusBadge status={data.status} />
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>RPS:</span>
                    <span className="font-mono">{data.requests_per_second}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Error Rate:</span>
                    <span className="font-mono">{data.error_rate}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Response Time:</span>
                    <span className="font-mono">{data.response_time}ms</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Memory:</span>
                    <span className="font-mono">{data.memory_usage}%</span>
                  </div>
                  <div className="flex justify-between">
                    <span>CPU:</span>
                    <span className="font-mono">{data.cpu_usage}%</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Tenant Analytics */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Top Tenants by Requests */}
        <Card>
          <CardHeader>
            <CardTitle>Top Tenants by Requests</CardTitle>
            <CardDescription>Most active tenants in the last hour</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {metrics.tenant_metrics.top_tenants_by_requests.map((tenant, index) => (
                <div key={tenant.tenant_id} className="flex items-center justify-between p-3 border rounded-lg">
                  <div className="flex items-center space-x-3">
                    <div className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-medium">
                      {index + 1}
                    </div>
                    <div>
                      <div className="font-medium">{tenant.tenant_id}</div>
                      <div className="text-sm text-gray-500">{tenant.samples} samples</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-medium">{tenant.requests} req/min</div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        {/* Utilization Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Tenant Utilization Distribution</CardTitle>
            <CardDescription>How tenants are using their allocated resources</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={utilizationPieData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percentage }) => `${name} ${percentage}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {utilizationPieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6'][index]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Alerts */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5" />
            Recent Alerts
          </CardTitle>
          <CardDescription>System alerts and notifications</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3 mb-4">
            <div className="text-center p-4 border rounded-lg">
              <div className="text-2xl font-bold text-red-600">{metrics.alert_metrics.critical_alerts}</div>
              <div className="text-sm text-gray-500">Critical</div>
            </div>
            <div className="text-center p-4 border rounded-lg">
              <div className="text-2xl font-bold text-yellow-600">{metrics.alert_metrics.warning_alerts}</div>
              <div className="text-sm text-gray-500">Warning</div>
            </div>
            <div className="text-center p-4 border rounded-lg">
              <div className="text-2xl font-bold text-blue-600">{metrics.alert_metrics.info_alerts}</div>
              <div className="text-sm text-gray-500">Info</div>
            </div>
          </div>
          <div className="space-y-3">
            {metrics.alert_metrics.recent_alerts.map((alert) => (
              <div key={alert.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center space-x-3">
                  <StatusBadge status={alert.severity} />
                  <div>
                    <div className="text-sm font-medium">{alert.message}</div>
                    <div className="text-xs text-gray-500">{alert.component} • {new Date(alert.timestamp).toLocaleString()}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
