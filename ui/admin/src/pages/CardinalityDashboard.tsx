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
  AlertTriangle, 
  CheckCircle, 
  XCircle,
  TrendingUp,
  TrendingDown,
  Shield,
  Database,
  BarChart3,
  Clock,
  Zap,
  Target,
  AlertCircle,
  RefreshCw,
  Filter
} from 'lucide-react';

// Cardinality metrics interfaces
interface CardinalityMetrics {
  total_series: number;
  total_labels: number;
  avg_series_per_request: number;
  avg_labels_per_series: number;
  max_series_in_request: number;
  max_labels_in_series: number;
  cardinality_violations: number;
  violation_rate: number;
}

interface CardinalityViolation {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_series: number;
  observed_labels: number;
  limit_exceeded: number;
}

interface CardinalityTrend {
  timestamp: string;
  avg_series_per_request: number;
  avg_labels_per_series: number;
  violation_count: number;
  total_requests: number;
}

interface TenantCardinality {
  tenant_id: string;
  name: string;
  current_series: number;
  current_labels: number;
  violation_count: number;
  last_violation: string;
  limits: {
    max_series_per_request: number;
    max_labels_per_series: number;
  };
}

interface CardinalityData {
  metrics: CardinalityMetrics;
  violations: CardinalityViolation[];
  trends: CardinalityTrend[];
  tenants: TenantCardinality[];
  alerts: CardinalityAlert[];
}

interface CardinalityAlert {
  id: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  message: string;
  timestamp: string;
  tenant_id?: string;
  metric: string;
  value: number;
  threshold: number;
  resolved: boolean;
}

// Status badge component
function StatusBadge({ status, message }: { status: string; message?: string }) {
  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'healthy':
        return { color: 'bg-green-100 text-green-800', icon: CheckCircle };
      case 'warning':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'critical':
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

// Severity badge component
function SeverityBadge({ severity }: { severity: string }) {
  const getSeverityConfig = (severity: string) => {
    switch (severity) {
      case 'critical':
        return { color: 'bg-red-100 text-red-800', icon: XCircle };
      case 'error':
        return { color: 'bg-orange-100 text-orange-800', icon: AlertTriangle };
      case 'warning':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'info':
        return { color: 'bg-blue-100 text-blue-800', icon: AlertCircle };
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: AlertCircle };
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

export function CardinalityDashboard() {
  const [timeRange, setTimeRange] = useState('1h');
  const [selectedTenant, setSelectedTenant] = useState<string>('all');

  const { data: cardinalityData, isLoading, error } = useQuery<CardinalityData>(
    ['cardinality', timeRange, selectedTenant],
    () => fetchCardinalityData(timeRange, selectedTenant),
    {
      refetchInterval: 10000, // Refetch every 10 seconds
      refetchIntervalInBackground: true,
      staleTime: 5000,
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Loading cardinality data...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-lg text-red-600">Failed to load cardinality data</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  const { metrics, violations, trends, tenants, alerts } = cardinalityData || {
    metrics: { total_series: 0, total_labels: 0, avg_series_per_request: 0, avg_labels_per_series: 0, max_series_in_request: 0, max_labels_in_series: 0, cardinality_violations: 0, violation_rate: 0 },
    violations: [],
    trends: [],
    tenants: [],
    alerts: []
  };

  // Calculate overall cardinality status
  const getCardinalityStatus = () => {
    if (metrics.violation_rate > 0.1) return 'critical';
    if (metrics.violation_rate > 0.05) return 'warning';
    return 'healthy';
  };

  const cardinalityStatus = getCardinalityStatus();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Cardinality Dashboard</h1>
          <p className="text-gray-500">Real-time monitoring of series and label cardinality</p>
        </div>
        <div className="flex items-center space-x-4">
          <StatusBadge status={cardinalityStatus} />
          <div className="flex items-center space-x-2 text-sm text-gray-500">
            <RefreshCw className="w-4 h-4 animate-spin" />
            <span>Auto-refresh (10s)</span>
          </div>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Series</CardTitle>
            <Database className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.total_series.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              Across all tenants
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Series/Request</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.avg_series_per_request.toFixed(1)}</div>
            <p className="text-xs text-muted-foreground">
              Per request average
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Labels/Series</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{metrics.avg_labels_per_series.toFixed(1)}</div>
            <p className="text-xs text-muted-foreground">
              Per series average
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Violation Rate</CardTitle>
            <Shield className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{(metrics.violation_rate * 100).toFixed(2)}%</div>
            <p className="text-xs text-muted-foreground">
              {metrics.cardinality_violations} violations
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Cardinality Trends */}
      <div className="grid gap-6 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Series per Request Trend</CardTitle>
            <CardDescription>Average series count over time</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={trends}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="timestamp" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="avg_series_per_request" stroke="#8884d8" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Labels per Series Trend</CardTitle>
            <CardDescription>Average label count over time</CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={trends}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="timestamp" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="avg_labels_per_series" stroke="#82ca9d" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Cardinality Violations */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Cardinality Violations</CardTitle>
          <CardDescription>Latest violations of cardinality limits</CardDescription>
        </CardHeader>
        <CardContent>
          {violations.length === 0 ? (
            <div className="flex items-center justify-center h-32 bg-gray-50 rounded-lg">
              <div className="text-center">
                <CheckCircle className="w-8 h-8 text-green-500 mx-auto mb-2" />
                <div className="text-lg text-gray-600">No cardinality violations</div>
                <div className="text-sm text-gray-500">All requests within limits</div>
              </div>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Timestamp</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Violation</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Observed</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Limit</th>
                    <th className="text-left py-3 px-4 font-medium text-gray-900">Exceeded</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {violations.slice(0, 10).map((violation, index) => (
                    <tr key={index} className="hover:bg-gray-50">
                      <td className="py-3 px-4 text-sm">
                        <div className="font-mono text-gray-900">
                          {new Date(violation.timestamp).toLocaleString()}
                        </div>
                      </td>
                      <td className="py-3 px-4">
                        <span className="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                          {violation.tenant_id}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <span className="inline-flex items-center px-2 py-1 text-xs font-medium bg-red-100 text-red-800 rounded">
                          {violation.reason}
                        </span>
                      </td>
                      <td className="py-3 px-4 font-mono text-sm">
                        {violation.observed_series || violation.observed_labels}
                      </td>
                      <td className="py-3 px-4 font-mono text-sm">
                        {violation.limit_exceeded}
                      </td>
                      <td className="py-3 px-4 font-mono text-sm text-red-600">
                        +{((violation.observed_series || violation.observed_labels) - violation.limit_exceeded)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Tenant Cardinality Overview */}
      <Card>
        <CardHeader>
          <CardTitle>Tenant Cardinality Overview</CardTitle>
          <CardDescription>Current cardinality status by tenant</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {tenants.map((tenant) => (
              <div key={tenant.tenant_id} className="p-4 border rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-medium">{tenant.name || tenant.tenant_id}</h4>
                  <Badge variant={tenant.violation_count > 0 ? "destructive" : "secondary"}>
                    {tenant.violation_count} violations
                  </Badge>
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Current Series:</span>
                    <span className="font-mono">{tenant.current_series.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Current Labels:</span>
                    <span className="font-mono">{tenant.current_labels.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Series Limit:</span>
                    <span className="font-mono">{tenant.limits.max_series_per_request.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Labels Limit:</span>
                    <span className="font-mono">{tenant.limits.max_labels_per_series}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Cardinality Alerts */}
      <Card>
        <CardHeader>
          <CardTitle>Cardinality Alerts</CardTitle>
          <CardDescription>Active alerts for cardinality issues</CardDescription>
        </CardHeader>
        <CardContent>
          {alerts.length === 0 ? (
            <div className="flex items-center justify-center h-32 bg-gray-50 rounded-lg">
              <div className="text-center">
                <CheckCircle className="w-8 h-8 text-green-500 mx-auto mb-2" />
                <div className="text-lg text-gray-600">No active alerts</div>
                <div className="text-sm text-gray-500">All cardinality metrics within thresholds</div>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              {alerts.map((alert) => (
                <div key={alert.id} className="p-4 border rounded-lg">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center space-x-2">
                      <SeverityBadge severity={alert.severity} />
                      <span className="font-medium">{alert.message}</span>
                    </div>
                    <span className="text-sm text-gray-500">
                      {new Date(alert.timestamp).toLocaleString()}
                    </span>
                  </div>
                  <div className="text-sm text-gray-600">
                    <div className="flex justify-between">
                      <span>Metric: {alert.metric}</span>
                      <span className="font-mono">Value: {alert.value}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Threshold: {alert.threshold}</span>
                      {alert.tenant_id && <span>Tenant: {alert.tenant_id}</span>}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// Real API call to fetch cardinality data
async function fetchCardinalityData(timeRange: string, tenant: string): Promise<CardinalityData> {
  try {
    const params = new URLSearchParams();
    if (timeRange) params.append('range', timeRange);
    if (tenant && tenant !== 'all') params.append('tenant', tenant);
    
    const response = await fetch(`/api/cardinality?${params.toString()}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Failed to fetch cardinality data:', error);
    
    // Return empty data structure on error
    return {
      metrics: {
        total_series: 0,
        total_labels: 0,
        avg_series_per_request: 0,
        avg_labels_per_series: 0,
        max_series_in_request: 0,
        max_labels_in_series: 0,
        cardinality_violations: 0,
        violation_rate: 0
      },
      violations: [],
      trends: [],
      tenants: [],
      alerts: []
    };
  }
}
