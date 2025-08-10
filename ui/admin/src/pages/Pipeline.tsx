import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { 
  Server, 
  Activity, 
  CheckCircle, 
  XCircle, 
  AlertTriangle, 
  Clock,
  Database,
  Network,
  Shield,
  Settings,
  BarChart3,
  TrendingUp,
  TrendingDown,
  Users
} from 'lucide-react';

// Component status interface
interface ComponentStatus {
  name: string;
  status: 'healthy' | 'warning' | 'error' | 'unknown';
  uptime: string;
  version: string;
  last_check: string;
  metrics: {
    requests_per_second: number;
    error_rate: number;
    response_time: number;
    memory_usage: number;
    cpu_usage: number;
  };
  endpoints: {
    health: string;
    metrics: string;
    ready: string;
  };
}

// Pipeline flow interface
interface PipelineFlow {
  stage: string;
  component: string;
  requests_per_second: number;
  success_rate: number;
  error_rate: number;
  avg_response_time: number;
  status: 'flowing' | 'blocked' | 'degraded';
}

// System overview interface
interface SystemOverview {
  total_requests_per_second: number;
  total_errors_per_second: number;
  overall_success_rate: number;
  avg_response_time: number;
  active_tenants: number;
  total_denials: number;
  components: ComponentStatus[];
  pipeline_flow: PipelineFlow[];
}

// Real API function - fetches actual pipeline status
async function fetchPipelineStatus(): Promise<SystemOverview> {
  try {
    const response = await fetch('/api/pipeline/status');
    if (!response.ok) {
      throw new Error(`Failed to fetch pipeline status: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Error fetching pipeline status:', error);
    // Return empty data structure on error
    return {
      total_requests_per_second: 0,
      total_errors_per_second: 0,
      overall_success_rate: 0,
      avg_response_time: 0,
      active_tenants: 0,
      total_denials: 0,
      components: [],
      pipeline_flow: []
    };
  }
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

// Flow status badge component
function FlowStatusBadge({ status }: { status: string }) {
  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'flowing':
        return { color: 'bg-green-100 text-green-800', icon: TrendingUp };
      case 'degraded':
        return { color: 'bg-yellow-100 text-yellow-800', icon: AlertTriangle };
      case 'blocked':
        return { color: 'bg-red-100 text-red-800', icon: TrendingDown };
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

export function Pipeline() {
  const { data: systemOverview, isLoading, error } = useQuery<SystemOverview>(
    ['pipeline-status'],
    fetchPipelineStatus,
    {
      refetchInterval: 10000, // Refetch every 10 seconds for real-time updates
      refetchIntervalInBackground: true,
      staleTime: 5000, // Consider data stale after 5 seconds
    }
  );

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">Loading pipeline status...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <div className="text-lg text-red-600 mb-2">Error loading pipeline status</div>
          <div className="text-sm text-gray-500">
            {error instanceof Error ? error.message : 'Unknown error occurred'}
          </div>
        </div>
      </div>
    );
  }

  if (!systemOverview) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-lg text-gray-600">No pipeline data available</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* System Overview */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total RPS</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemOverview.total_requests_per_second.toLocaleString()}</div>
            <p className="text-xs text-muted-foreground">
              {systemOverview.total_errors_per_second} errors/sec
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Success Rate</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemOverview.overall_success_rate.toFixed(1)}%</div>
            <p className="text-xs text-muted-foreground">
              {systemOverview.total_denials} denials today
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemOverview.avg_response_time}ms</div>
            <p className="text-xs text-muted-foreground">
              End-to-end latency
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Tenants</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemOverview.active_tenants}</div>
            <p className="text-xs text-muted-foreground">
              With active traffic
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Component Status */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            Component Status
          </CardTitle>
          <CardDescription>Health and performance of all system components</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {systemOverview.components.map((component) => (
              <div key={component.name} className="flex items-center justify-between p-4 border rounded-lg">
                <div className="flex items-center space-x-4">
                  <div className="flex items-center space-x-2">
                    <StatusBadge status={component.status} />
                    <span className="font-medium">{component.name}</span>
                  </div>
                  <div className="text-sm text-gray-500">
                    v{component.version} • {component.uptime}
                  </div>
                </div>
                
                <div className="flex items-center space-x-6">
                  <div className="text-right">
                    <div className="text-sm font-medium">{component.metrics.requests_per_second} RPS</div>
                    <div className="text-xs text-gray-500">{component.metrics.error_rate}% error rate</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{component.metrics.response_time}ms</div>
                    <div className="text-xs text-gray-500">avg response</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{component.metrics.memory_usage}%</div>
                    <div className="text-xs text-gray-500">memory</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{component.metrics.cpu_usage}%</div>
                    <div className="text-xs text-gray-500">CPU</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Pipeline Flow */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <BarChart3 className="h-5 w-5" />
            Pipeline Flow
          </CardTitle>
          <CardDescription>Request flow through the edge enforcement pipeline</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {systemOverview.pipeline_flow.map((flow, index) => (
              <div key={flow.stage} className="flex items-center justify-between p-4 border rounded-lg">
                <div className="flex items-center space-x-4">
                  <div className="flex items-center space-x-2">
                    <FlowStatusBadge status={flow.status} />
                    <span className="font-medium">{flow.stage}</span>
                  </div>
                  <div className="text-sm text-gray-500">
                    {flow.component}
                  </div>
                </div>
                
                <div className="flex items-center space-x-6">
                  <div className="text-right">
                    <div className="text-sm font-medium">{flow.requests_per_second} RPS</div>
                    <div className="text-xs text-gray-500">throughput</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{flow.success_rate}%</div>
                    <div className="text-xs text-gray-500">success rate</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{flow.error_rate}%</div>
                    <div className="text-xs text-gray-500">error rate</div>
                  </div>
                  <div className="text-right">
                    <div className="text-sm font-medium">{flow.avg_response_time}ms</div>
                    <div className="text-xs text-gray-500">avg latency</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="h-5 w-5" />
            Quick Actions
          </CardTitle>
          <CardDescription>Common monitoring and troubleshooting actions</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <button className="p-4 border rounded-lg hover:bg-gray-50 text-left">
              <div className="font-medium">View Logs</div>
              <div className="text-sm text-gray-500">Check component logs</div>
            </button>
            <button className="p-4 border rounded-lg hover:bg-gray-50 text-left">
              <div className="font-medium">Metrics</div>
              <div className="text-sm text-gray-500">Detailed metrics</div>
            </button>
            <button className="p-4 border rounded-lg hover:bg-gray-50 text-left">
              <div className="font-medium">Health Check</div>
              <div className="text-sm text-gray-500">Run health checks</div>
            </button>
            <button className="p-4 border rounded-lg hover:bg-gray-50 text-left">
              <div className="font-medium">Restart</div>
              <div className="text-sm text-gray-500">Restart components</div>
            </button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
