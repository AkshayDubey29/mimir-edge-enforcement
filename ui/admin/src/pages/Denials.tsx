import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Info, Download, TrendingUp, AlertTriangle, CheckCircle, XCircle, Clock, Database, Zap, FileText } from 'lucide-react';

// Utility function to format bytes in human-readable format
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// Utility function to get relative time
function getRelativeTime(timestamp: string): string {
  const now = new Date();
  const time = new Date(timestamp);
  const diffMs = now.getTime() - time.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${diffDays}d ago`;
}

// Enhanced interfaces
interface DenialInsights {
  samples_exceeded_by: number;
  body_size_exceeded_by: number;
  series_exceeded_by: number;
  labels_exceeded_by: number;
  utilization_percentage: number;
  trend_direction: string;
  frequency_in_period: number;
}

interface TenantLimits {
  samples_per_second: number;
  burst_pct: number;
  max_body_bytes: number;
  max_labels_per_series: number;
  max_label_value_length: number;
  max_series_per_request: number;
}

interface EnhancedDenial {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_samples: number;
  observed_body_bytes: number;
  observed_series?: number;
  observed_labels?: number;
  tenant_limits: TenantLimits;
  insights: DenialInsights;
  recommendations: string[];
  severity: string;
  category: string;
}

interface DenialTrend {
  tenant_id: string;
  reason: string;
  period: string;
  count: number;
  trend_direction: string;
  last_occurrence: string;
  first_occurrence: string;
}

interface Denial {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_samples: number;
  observed_body_bytes: number;
}

export function Denials() {
  const [view, setView] = useState<'enhanced' | 'basic' | 'trends'>('enhanced');
  const [timeRange, setTimeRange] = useState('1h');
  const [selectedTenant, setSelectedTenant] = useState('');

  // Enhanced denials query
  const { data: enhancedData, isLoading: enhancedLoading, error: enhancedError } = useQuery({ 
    queryKey: ['enhanced-denials', timeRange, selectedTenant], 
    queryFn: () => fetchEnhancedDenials(timeRange, selectedTenant),
    refetchInterval: 10000, // Auto-refresh every 10 seconds
    refetchIntervalInBackground: true,
    enabled: view === 'enhanced'
  });

  // Trends query
  const { data: trendsData, isLoading: trendsLoading, error: trendsError } = useQuery({ 
    queryKey: ['denial-trends', timeRange, selectedTenant], 
    queryFn: () => fetchDenialTrends(timeRange, selectedTenant),
    refetchInterval: 30000, // Auto-refresh every 30 seconds
    refetchIntervalInBackground: true,
    enabled: view === 'trends'
  });

  // Basic denials query (fallback)
  const { data: basicData, isLoading: basicLoading, error: basicError } = useQuery({ 
    queryKey: ['basic-denials', timeRange, selectedTenant], 
    queryFn: () => fetchBasicDenials(timeRange, selectedTenant),
    refetchInterval: 5000, // Auto-refresh every 5 seconds
    refetchIntervalInBackground: true,
    enabled: view === 'basic'
  });

  const isLoading = enhancedLoading || trendsLoading || basicLoading;
  const error = enhancedError || trendsError || basicError;

  if (isLoading) return <div className="flex items-center justify-center h-64"><div className="text-lg text-gray-600">Loading denials...</div></div>;
  if (error) return <div className="flex items-center justify-center h-64"><div className="text-lg text-red-600">Failed to load denials: {error instanceof Error ? error.message : 'Unknown error'}</div></div>;

  const enhancedDenials: EnhancedDenial[] = enhancedData?.denials || [];
  const trends: DenialTrend[] = trendsData?.trends || [];
  const basicDenials: Denial[] = basicData?.denials || [];

  const handleExport = () => {
    const dataToExport = view === 'enhanced' ? enhancedDenials : 
                        view === 'trends' ? trends : basicDenials;
    const csvContent = generateCSV(dataToExport, view);
    downloadCSV(csvContent, `denials-${view}-${timeRange}-${Date.now()}.csv`);
  };

  return (
    <div className="space-y-6">
      {/* Header with Controls */}
      <div className="flex flex-col space-y-4 lg:flex-row lg:items-center lg:justify-between lg:space-y-0">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Recent Denials</h1>
          <p className="text-gray-600 mt-1">Monitor and analyze request denials with detailed insights</p>
        </div>
        
        <div className="flex flex-wrap items-center gap-4">
          {/* View Toggle */}
          <div className="flex items-center space-x-2 bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setView('enhanced')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                view === 'enhanced' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <Database className="w-4 h-4 mr-1 inline" />
              Enhanced
            </button>
            <button
              onClick={() => setView('trends')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                view === 'trends' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <TrendingUp className="w-4 h-4 mr-1 inline" />
              Trends
            </button>
            <button
              onClick={() => setView('basic')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                view === 'basic' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <FileText className="w-4 h-4 mr-1 inline" />
              Basic
            </button>
          </div>

          {/* Time Range */}
          <select 
            value={timeRange} 
            onChange={(e) => setTimeRange(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="15m">Last 15 minutes</option>
            <option value="1h">Last hour</option>
            <option value="6h">Last 6 hours</option>
            <option value="24h">Last 24 hours</option>
            <option value="7d">Last 7 days</option>
          </select>

          {/* Tenant Filter */}
          <input
            type="text"
            placeholder="Filter by tenant..."
            value={selectedTenant}
            onChange={(e) => setSelectedTenant(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />

          {/* Export Button */}
          <Button onClick={handleExport} className="inline-flex items-center">
            <Download className="w-4 h-4 mr-2" />
            Export CSV
          </Button>
        </div>
      </div>

      {/* Information Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="p-4">
          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0"><Info className="w-5 h-5 text-blue-500" /></div>
            <div>
              <h3 className="text-sm font-medium text-gray-900">Denial Reasons</h3>
              <p className="text-xs text-gray-600 mt-1">Common reasons include rate limiting, cardinality violations, and parsing errors.</p>
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0"><Database className="w-5 h-5 text-green-500" /></div>
            <div>
              <h3 className="text-sm font-medium text-gray-900">Body Size</h3>
              <p className="text-xs text-gray-600 mt-1">Request body size in bytes. Large payloads may be compressed with gzip/snappy.</p>
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0"><Zap className="w-5 h-5 text-yellow-500" /></div>
            <div>
              <h3 className="text-sm font-medium text-gray-900">Utilization</h3>
              <p className="text-xs text-gray-600 mt-1">Percentage of limit utilization. High values indicate approaching limits.</p>
            </div>
          </div>
        </Card>
        <Card className="p-4">
          <div className="flex items-start space-x-3">
            <div className="flex-shrink-0"><CheckCircle className="w-5 h-5 text-purple-500" /></div>
            <div>
              <h3 className="text-sm font-medium text-gray-900">Recommendations</h3>
              <p className="text-xs text-gray-600 mt-1">Actionable suggestions to resolve denial issues and optimize requests.</p>
            </div>
          </div>
        </Card>
      </div>

      {/* Content based on view */}
      {view === 'enhanced' && renderEnhancedView(enhancedDenials, enhancedData?.metadata)}
      {view === 'trends' && renderTrendsView(trends, trendsData?.metadata)}
      {view === 'basic' && renderBasicView(basicDenials)}
    </div>
  );
}

// Render functions
function renderEnhancedView(denials: EnhancedDenial[], metadata?: any) {
  if (denials.length === 0) {
    return (
      <Card className="p-8 text-center">
        <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">No Denials Found</h3>
        <p className="text-gray-600">All requests are being allowed in the selected timeframe.</p>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {/* Metadata */}
      {metadata && (
        <div className="bg-blue-50 p-4 rounded-lg">
          <div className="flex items-center justify-between text-sm">
            <span className="text-blue-700">
              <Clock className="w-4 h-4 inline mr-1" />
              Generated: {new Date(metadata.generated_at).toLocaleString()}
            </span>
            <span className="text-blue-700">Total: {metadata.total_count}</span>
          </div>
        </div>
      )}

      {/* Enhanced denials cards */}
      <div className="space-y-4">
        {denials.map((denial, index) => (
          <Card key={index} className="p-6">
            <div className="space-y-4">
              {/* Header */}
              <div className="flex items-start justify-between">
                <div className="flex items-center space-x-3">
                  <span className="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                    {denial.tenant_id}
                  </span>
                  <Badge className={`${getSeverityColor(denial.severity)} border`}>
                    {denial.severity.toUpperCase()}
                  </Badge>
                </div>
                <div className="text-right text-sm text-gray-500">
                  <div>{new Date(denial.timestamp).toLocaleString()}</div>
                  <div>{getRelativeTime(denial.timestamp)}</div>
                </div>
              </div>

              {/* Denial reason */}
              <Badge variant="outline" className="text-red-700 border-red-300">
                {denial.reason}
              </Badge>

              {/* Metrics */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div>
                  <div className="font-medium text-gray-700">Samples</div>
                  <div className="font-mono">{denial.observed_samples.toLocaleString()}</div>
                </div>
                <div>
                  <div className="font-medium text-gray-700">Body Size</div>
                  <div className="font-mono">{formatBytes(denial.observed_body_bytes)}</div>
                </div>
                <div>
                  <div className="font-medium text-gray-700">Utilization</div>
                  <div className="font-mono">{denial.insights.utilization_percentage.toFixed(1)}%</div>
                </div>
                <div>
                  <div className="font-medium text-gray-700">Frequency</div>
                  <div className="font-mono">{denial.insights.frequency_in_period}</div>
                </div>
              </div>

              {/* Recommendations */}
              {denial.recommendations.length > 0 && (
                <div className="bg-blue-50 p-4 rounded-lg">
                  <h4 className="font-medium text-blue-900 mb-2">Recommendations</h4>
                  <ul className="space-y-1 text-sm text-blue-800">
                    {denial.recommendations.map((rec, idx) => (
                      <li key={idx}>• {rec}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

function renderTrendsView(trends: DenialTrend[], metadata?: any) {
  if (trends.length === 0) {
    return (
      <Card className="p-8 text-center">
        <TrendingUp className="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">No Trends Available</h3>
        <p className="text-gray-600">No denial patterns found in the selected timeframe.</p>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      {/* Metadata */}
      {metadata && (
        <div className="bg-green-50 p-4 rounded-lg">
          <div className="flex items-center justify-between text-sm">
            <span className="text-green-700">
              <TrendingUp className="w-4 h-4 inline mr-1" />
              Generated: {new Date(metadata.generated_at).toLocaleString()}
            </span>
            <span className="text-green-700">Trends: {metadata.total_trends}</span>
          </div>
        </div>
      )}

      {/* Trends grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {trends.map((trend, index) => (
          <Card key={index} className="p-4">
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                  {trend.tenant_id}
                </span>
                <Badge variant="outline">{trend.count}</Badge>
              </div>
              
              <div>
                <div className="font-medium text-gray-900">{trend.reason}</div>
                <div className="text-sm text-gray-600 capitalize">{trend.trend_direction} trend</div>
              </div>

              <div className="text-xs text-gray-500 space-y-1">
                <div>First: {getRelativeTime(trend.first_occurrence)}</div>
                <div>Last: {getRelativeTime(trend.last_occurrence)}</div>
                <div>Period: {trend.period}</div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

function renderBasicView(denials: Denial[]) {
  if (denials.length === 0) {
    return (
      <Card className="p-8 text-center">
        <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-gray-900 mb-2">No Denials Found</h3>
        <p className="text-gray-600">All requests are being allowed in the selected timeframe.</p>
      </Card>
    );
  }

  return (
    <Card className="overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="text-left py-3 px-4 font-medium text-gray-900">Timestamp</th>
              <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant ID</th>
              <th className="text-left py-3 px-4 font-medium text-gray-900">Denial Reason</th>
              <th className="text-left py-3 px-4 font-medium text-gray-900">Observed Samples</th>
              <th className="text-left py-3 px-4 font-medium text-gray-900">Body Size</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {denials.map((denial: Denial, index: number) => (
              <tr key={index} className="hover:bg-gray-50">
                <td className="py-3 px-4 text-sm">
                  <div className="font-mono text-gray-900">
                    {new Date(denial.timestamp).toLocaleString()}
                  </div>
                  <div className="text-xs text-gray-500">
                    {getRelativeTime(denial.timestamp)}
                  </div>
                </td>
                <td className="py-3 px-4">
                  <span className="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                    {denial.tenant_id}
                  </span>
                </td>
                <td className="py-3 px-4">
                  <Badge variant="outline" className="text-red-700 border-red-300">
                    {denial.reason}
                  </Badge>
                </td>
                <td className="py-3 px-4 font-mono text-sm">
                  {denial.observed_samples?.toLocaleString() || 'N/A'}
                </td>
                <td className="py-3 px-4 font-mono text-sm">
                  {denial.observed_body_bytes ? formatBytes(denial.observed_body_bytes) : 'N/A'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

// Helper functions
function getSeverityColor(severity: string) {
  switch (severity) {
    case 'critical': return 'bg-red-100 text-red-800 border-red-200';
    case 'high': return 'bg-orange-100 text-orange-800 border-orange-200';
    case 'medium': return 'bg-yellow-100 text-yellow-800 border-yellow-200';
    case 'low': return 'bg-blue-100 text-blue-800 border-blue-200';
    default: return 'bg-gray-100 text-gray-800 border-gray-200';
  }
}

// Export functionality
function generateCSV(data: any[], view: string): string {
  if (view === 'enhanced') {
    const enhancedData = data as EnhancedDenial[];
    const headers = [
      'Timestamp', 'Tenant ID', 'Reason', 'Category', 'Severity',
      'Observed Samples', 'Body Size (bytes)', 'Utilization %',
      'Recommendations'
    ];
    
    const csvRows = [
      headers.join(','),
      ...enhancedData.map(denial => [
        denial.timestamp,
        denial.tenant_id,
        denial.reason,
        denial.category,
        denial.severity,
        denial.observed_samples,
        denial.observed_body_bytes,
        denial.insights.utilization_percentage.toFixed(2),
        `"${denial.recommendations.join('; ')}"`
      ].join(','))
    ];
    
    return csvRows.join('\n');
  } else if (view === 'trends') {
    const trendsData = data as DenialTrend[];
    const headers = [
      'Tenant ID', 'Reason', 'Count', 'Trend Direction', 'Period',
      'First Occurrence', 'Last Occurrence'
    ];
    
    const csvRows = [
      headers.join(','),
      ...trendsData.map(trend => [
        trend.tenant_id,
        trend.reason,
        trend.count,
        trend.trend_direction,
        trend.period,
        trend.first_occurrence,
        trend.last_occurrence
      ].join(','))
    ];
    
    return csvRows.join('\n');
  } else {
    // Basic view
    const basicData = data as Denial[];
    const headers = [
      'Timestamp', 'Tenant ID', 'Reason', 'Observed Samples', 'Body Size (bytes)'
    ];
    
    const csvRows = [
      headers.join(','),
      ...basicData.map(denial => [
        denial.timestamp,
        denial.tenant_id,
        denial.reason,
        denial.observed_samples,
        denial.observed_body_bytes
      ].join(','))
    ];
    
    return csvRows.join('\n');
  }
}

function downloadCSV(csvContent: string, filename: string) {
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  
  if (link.download !== undefined) {
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }
}

// API functions
async function fetchEnhancedDenials(timeRange: string, tenant: string) {
  const params = new URLSearchParams({
    since: timeRange,
    ...(tenant && { tenant })
  });
  const res = await fetch(`/api/denials/enhanced?${params}`);
  if (!res.ok) throw new Error('Failed to fetch enhanced denials');
  return res.json();
}

async function fetchDenialTrends(timeRange: string, tenant: string) {
  const params = new URLSearchParams({
    since: timeRange,
    ...(tenant && { tenant })
  });
  const res = await fetch(`/api/denials/trends?${params}`);
  if (!res.ok) throw new Error('Failed to fetch denial trends');
  return res.json();
}

async function fetchBasicDenials(timeRange: string, tenant: string) {
  const params = new URLSearchParams({
    since: timeRange,
    ...(tenant && { tenant: tenant || '*' })
  });
  const res = await fetch(`/api/denials?${params}`);
  if (!res.ok) throw new Error('Failed to fetch basic denials');
  const data = await res.json();
  return { denials: data.denials || [] };
}