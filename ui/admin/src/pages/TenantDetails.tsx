import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
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
  Cell
} from 'recharts';
import { 
  User, 
  Activity, 
  Clock, 
  AlertTriangle, 
  CheckCircle, 
  XCircle,
  TrendingUp,
  TrendingDown,
  Shield,
  Settings,
  BarChart3,
  Calendar,
  Zap,
  Database
} from 'lucide-react';

// Tenant details interface
interface TenantDetails {
  id: string;
  name: string;
  status: 'active' | 'inactive' | 'suspended';
  created_at: string;
  last_activity: string;
  limits: {
    samples_per_second: number;
    burst_percent: number;
    max_body_bytes: number;
    max_series_per_query: number;
    max_global_series_per_user: number;
    max_global_series_per_metric: number;
    max_global_exemplars_per_user: number;
    ingestion_rate: number;
    ingestion_burst_size: number;
  };
  metrics: {
    current_samples_per_second: number;
    current_series: number;
    total_requests: number;
    allowed_requests: number;
    denied_requests: number;
    allow_rate: number;
    deny_rate: number;
    avg_response_time: number;
    error_rate: number;
    utilization_pct: number;
  };
  request_history: Array<{
    timestamp: string;
    requests: number;
    samples: number;
    denials: number;
    avg_response_time: number;
  }>;
  enforcement_history: Array<{
    timestamp: string;
    reason: string;
    limit_type: string;
    current_value: number;
    limit_value: number;
    action: 'allowed' | 'denied';
  }>;
  alerts: Array<{
    id: string;
    severity: 'info' | 'warning' | 'error';
    message: string;
    timestamp: string;
    resolved: boolean;
  }>;
}

// Mock data for tenant details
const mockTenantDetails: TenantDetails = {
  id: 'tenant-123',
  name: 'Production App',
  status: 'active',
  created_at: '2024-01-01T00:00:00Z',
  last_activity: '2024-01-15T10:30:00Z',
  limits: {
    samples_per_second: 10000,
    burst_percent: 50,
    max_body_bytes: 1048576,
    max_series_per_query: 1000,
    max_global_series_per_user: 100000,
    max_global_series_per_metric: 10000,
    max_global_exemplars_per_user: 1000,
    ingestion_rate: 10000,
    ingestion_burst_size: 15000
  },
  metrics: {
    current_samples_per_second: 8500,
    current_series: 75000,
    total_requests: 125000,
    allowed_requests: 124500,
    denied_requests: 500,
    allow_rate: 99.6,
    deny_rate: 0.4,
    avg_response_time: 165,
    error_rate: 0.2,
    utilization_pct: 85
  },
  request_history: Array.from({ length: 24 }, (_, i) => ({
    timestamp: new Date(Date.now() - (23 - i) * 3600000).toISOString(),
    requests: Math.floor(Math.random() * 1000) + 500,
    samples: Math.floor(Math.random() * 5000) + 3000,
    denials: Math.floor(Math.random() * 20) + 5,
    avg_response_time: Math.floor(Math.random() * 100) + 100
  })),
  enforcement_history: [
    {
      timestamp: '2024-01-15T10:25:00Z',
      reason: 'Samples per second limit exceeded',
      limit_type: 'samples_per_second',
      current_value: 10500,
      limit_value: 10000,
      action: 'denied'
    },
    {
      timestamp: '2024-01-15T10:20:00Z',
      reason: 'Request within limits',
      limit_type: 'samples_per_second',
      current_value: 8500,
      limit_value: 10000,
      action: 'allowed'
    },
    {
      timestamp: '2024-01-15T10:15:00Z',
      reason: 'Burst limit exceeded',
      limit_type: 'burst_percent',
      current_value: 60,
      limit_value: 50,
      action: 'denied'
    }
  ],
  alerts: [
    {
      id: 'alert-1',
      severity: 'warning',
      message: 'High utilization detected (85%)',
      timestamp: '2024-01-15T10:00:00Z',
      resolved: false
    },
    {
      id: 'alert-2',
      severity: 'info',
      message: 'Tenant limits updated',
      timestamp: '2024-01-15T09:30:00Z',
      resolved: true
    }
  ]
};

// Mock API function
async function fetchTenantDetails(tenantId: string): Promise<TenantDetails> {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 500));
  return mockTenantDetails;
}

// Status badge component
function StatusBadge({ status }: { status: string }) {
  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'active':
        return { color: 'bg-green-100 text-green-800', icon: CheckCircle };
      case 'inactive':
        return { color: 'bg-gray-100 text-gray-800', icon: Clock };
      case 'suspended':
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

// Severity badge component
function SeverityBadge({ severity }: { severity: string }) {
  const getSeverityConfig = (severity: string) => {
    switch (severity) {
      case 'error':
        return { color: 'bg-red-100 text-red-800', icon: XCircle };
      case 'warning':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'info':
        return { color: 'bg-blue-100 text-blue-800', icon: CheckCircle };
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: Clock };
    }
  };

  const config = getSeverityConfig(severity);
  const Icon = config.icon;

  return (
    <Badge className={config.color}>
      <Icon className="w-3 h-3 mr-1" />
      {severity.charAt(0).toUpperCase() + severity.slice(1)}
    </Badge>
  );
}

export function TenantDetails() {
  const { tenantId } = useParams<{ tenantId: string }>();
  const [timeRange, setTimeRange] = useState('24h');

  const { data: tenantDetails, isLoading, error } = useQuery<TenantDetails>(
    ['tenant-details', tenantId],
    () => fetchTenantDetails(tenantId!),
    {
      refetchInterval: 30000, // Refetch every 30 seconds
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Loading tenant details...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-lg text-red-600 mb-2">Error loading tenant details</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  if (!tenantDetails) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Tenant not found</div>
      </div>
    );
  }

  // Prepare chart data
  const requestHistoryData = tenantDetails.request_history.map(item => ({
    time: new Date(item.timestamp).toLocaleTimeString(),
    requests: item.requests,
    samples: item.samples,
    denials: item.denials,
    response_time: item.avg_response_time
  }));

  const enforcementPieData = [
    { name: 'Allowed', value: tenantDetails.metrics.allowed_requests, color: '#10b981' },
    { name: 'Denied', value: tenantDetails.metrics.denied_requests, color: '#ef4444' }
  ];

  return (
    <div className="space-y-6">
      {/* Tenant Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">{tenantDetails.name}</h1>
          <p className="text-gray-500">Tenant ID: {tenantDetails.id}</p>
        </div>
        <div className="flex items-center space-x-4">
          <StatusBadge status={tenantDetails.status} />
          <button className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
            Edit Limits
          </button>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Current Samples/sec</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{tenantDetails.metrics.current_samples_per_second.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              {tenantDetails.metrics.utilization_pct}% of limit
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Allow Rate</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{tenantDetails.metrics.allow_rate}%</div>
            <p className="text-xs text-muted-foreground">
              {tenantDetails.metrics.allowed_requests.toLocaleString()} requests
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Deny Rate</CardTitle>
            <XCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{tenantDetails.metrics.deny_rate}%</div>
            <p className="text-xs text-muted-foreground">
              {tenantDetails.metrics.denied_requests.toLocaleString()} requests
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{tenantDetails.metrics.avg_response_time}ms</div>
            <p className="text-xs text-muted-foreground">
              {tenantDetails.metrics.error_rate}% error rate
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Charts Row */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Request History Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Request History (24h)</CardTitle>
            <CardDescription>Requests, samples, and denials over time</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={requestHistoryData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="requests" fill="#3b82f6" name="Requests" />
                <Bar dataKey="samples" fill="#10b981" name="Samples" />
                <Bar dataKey="denials" fill="#ef4444" name="Denials" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Enforcement Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>Enforcement Distribution</CardTitle>
            <CardDescription>Allowed vs denied requests</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={enforcementPieData}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {enforcementPieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Limits and Enforcement */}
      <div className="grid gap-6 md:grid-cols-2">
        {/* Current Limits */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5" />
              Current Limits
            </CardTitle>
            <CardDescription>Configured limits for this tenant</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Samples per second</span>
                <span className="text-sm">{tenantDetails.limits.samples_per_second.toLocaleString()}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Burst percent</span>
                <span className="text-sm">{tenantDetails.limits.burst_percent}%</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Max body bytes</span>
                <span className="text-sm">{tenantDetails.limits.max_body_bytes.toLocaleString()}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Max series per query</span>
                <span className="text-sm">{tenantDetails.limits.max_series_per_query.toLocaleString()}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm font-medium">Ingestion rate</span>
                <span className="text-sm">{tenantDetails.limits.ingestion_rate.toLocaleString()}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Recent Enforcement Actions */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="h-5 w-5" />
              Recent Enforcement Actions
            </CardTitle>
            <CardDescription>Latest limit enforcement decisions</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {tenantDetails.enforcement_history.slice(0, 5).map((action, index) => (
                <div key={index} className="flex items-center justify-between p-3 border rounded-lg">
                  <div>
                    <div className="text-sm font-medium">{action.reason}</div>
                    <div className="text-xs text-gray-500">{action.limit_type}</div>
                  </div>
                  <div className="text-right">
                    <Badge className={action.action === 'allowed' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}>
                      {action.action}
                    </Badge>
                    <div className="text-xs text-gray-500 mt-1">
                      {action.current_value} / {action.limit_value}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Alerts */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5" />
            Active Alerts
          </CardTitle>
          <CardDescription>Current alerts and notifications for this tenant</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {tenantDetails.alerts.map((alert) => (
              <div key={alert.id} className="flex items-center justify-between p-3 border rounded-lg">
                <div className="flex items-center space-x-3">
                  <SeverityBadge severity={alert.severity} />
                  <div>
                    <div className="text-sm font-medium">{alert.message}</div>
                    <div className="text-xs text-gray-500">{new Date(alert.timestamp).toLocaleString()}</div>
                  </div>
                </div>
                <div>
                  {alert.resolved ? (
                    <Badge className="bg-green-100 text-green-800">Resolved</Badge>
                  ) : (
                    <Badge className="bg-yellow-100 text-yellow-800">Active</Badge>
                  )}
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
