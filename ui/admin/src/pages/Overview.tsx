import React, { useState } from 'react';
import { useQuery } from 'react-query';
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
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { TrendingUp, TrendingDown, Activity, Users, AlertTriangle, CheckCircle } from 'lucide-react';

// Mock data - replace with actual API calls
const mockOverviewData = {
  stats: {
    total_requests: 1250000,
    allowed_requests: 1187500,
    denied_requests: 62500,
    allow_percentage: 95.0,
    active_tenants: 42
  },
  top_tenants: [
    { id: 'tenant-1', name: 'Production', rps: 1500, samples_per_sec: 50000, deny_rate: 2.1 },
    { id: 'tenant-2', name: 'Staging', rps: 800, samples_per_sec: 25000, deny_rate: 1.5 },
    { id: 'tenant-3', name: 'Development', rps: 300, samples_per_sec: 10000, deny_rate: 0.8 },
  ]
};

const timeRanges = [
  { value: '5m', label: 'Last 5 minutes' },
  { value: '1h', label: 'Last hour' },
  { value: '24h', label: 'Last 24 hours' },
  { value: '7d', label: 'Last 7 days' },
];

export function Overview() {
  const [timeRange, setTimeRange] = useState('1h');

  const { data: overviewData, isLoading, error } = useQuery(
    ['overview', timeRange],
    () => fetchOverviewData(timeRange),
    {
      refetchInterval: 30000, // Refetch every 30 seconds
      initialData: mockOverviewData,
    }
  );

  if (isLoading) {
    return <div>Loading...</div>;
  }

  if (error) {
    return <div>Error loading overview data</div>;
  }

  const { stats, top_tenants } = overviewData;

  // Prepare chart data
  const requestData = [
    { name: 'Allowed', value: stats.allowed_requests, color: '#10b981' },
    { name: 'Denied', value: stats.denied_requests, color: '#ef4444' },
  ];

  const tenantChartData = top_tenants.map(tenant => ({
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
          <p className="text-gray-600">Monitor your Mimir edge enforcement system</p>
        </div>
        <Select value={timeRange} onValueChange={setTimeRange}>
          <SelectTrigger className="w-48">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {timeRanges.map((range) => (
              <SelectItem key={range.value} value={range.value}>
                {range.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
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
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
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
                {top_tenants.map((tenant) => (
                  <tr key={tenant.id} className="border-b hover:bg-gray-50">
                    <td className="py-3 px-4 font-medium">{tenant.name}</td>
                    <td className="py-3 px-4">{tenant.rps.toLocaleString()}</td>
                    <td className="py-3 px-4">{tenant.samples_per_sec.toLocaleString()}</td>
                    <td className="py-3 px-4">
                      <Badge variant={tenant.deny_rate > 2 ? "destructive" : "secondary"}>
                        {tenant.deny_rate.toFixed(1)}%
                      </Badge>
                    </td>
                    <td className="py-3 px-4">
                      <Badge variant="outline" className="text-green-600">
                        Active
                      </Badge>
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

// Mock API function - replace with actual implementation
async function fetchOverviewData(timeRange: string) {
  // In a real implementation, this would call the RLS admin API
  // const response = await fetch(`/api/overview?range=${timeRange}`);
  // return response.json();
  
  // For now, return mock data
  return mockOverviewData;
} 