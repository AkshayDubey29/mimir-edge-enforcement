import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { AlertTriangle, CheckCircle, Clock, Loader, Info, TrendingUp, BarChart3, FileText, AlertCircle, Zap } from 'lucide-react';

// Enhanced interfaces for detailed denial information
interface DenialDetail {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_samples: number;
  observed_body_bytes: number;
  observed_series?: number;
  observed_labels?: number;
  limit_exceeded?: number;
  sample_metrics?: SampleMetric[];
}

interface SampleMetric {
  metric_name: string;
  labels: Record<string, string>;
  value: number;
  timestamp: number;
  series_hash?: string;
}

interface DenialAnalysis {
  category: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  explanation: string;
  impact: string;
  recommendations: string[];
  limit_info?: {
    type: string;
    current_limit: number;
    observed_value: number;
    utilization_percent: number;
  };
}

// Utility functions
function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function getRelativeTime(timestamp: string): string {
  const now = new Date();
  const time = new Date(timestamp);
  const diffMs = now.getTime() - time.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${Math.floor(diffMs / 86400000)}d ago`;
}

// Analyze denial reason and provide detailed information
function analyzeDenial(denial: DenialDetail): DenialAnalysis {
  const reason = denial.reason.toLowerCase();
  
  if (reason.includes('parse_failed')) {
    return {
      category: 'Data Format Error',
      severity: 'medium',
      explanation: 'The request payload could not be parsed as valid Prometheus remote write format. This usually indicates malformed protobuf data, incorrect compression, or invalid metric structure.',
      impact: 'Data ingestion failed completely. No metrics from this request were processed.',
      recommendations: [
        'Verify the remote write client is using correct Prometheus protobuf format',
        'Check if gzip/snappy compression is applied correctly',
        'Validate metric names and labels follow Prometheus naming conventions',
        'Test with a minimal valid payload to isolate the issue'
      ],
      limit_info: {
        type: 'Parsing',
        current_limit: 0,
        observed_value: denial.observed_body_bytes,
        utilization_percent: 100
      }
    };
  }
  
  if (reason.includes('samples') || reason.includes('rate')) {
    const expectedLimit = 1000; // Default samples per second limit
    return {
      category: 'Rate Limiting',
      severity: denial.observed_samples > expectedLimit * 2 ? 'high' : 'medium',
      explanation: `The request exceeded the samples per second rate limit. Observed ${denial.observed_samples} samples, which exceeds the tenant's configured limit.`,
      impact: 'Request was rejected to prevent system overload. Metrics data was not ingested.',
      recommendations: [
        'Reduce the frequency of metric collection',
        'Implement client-side batching with appropriate delays',
        'Contact administrator to review rate limits for this tenant',
        'Consider using recording rules to pre-aggregate high-cardinality metrics'
      ],
      limit_info: {
        type: 'Samples per Second',
        current_limit: expectedLimit,
        observed_value: denial.observed_samples,
        utilization_percent: (denial.observed_samples / expectedLimit) * 100
      }
    };
  }
  
  if (reason.includes('body') || reason.includes('size')) {
    const expectedLimit = 1048576; // 1MB default limit
    return {
      category: 'Payload Size Limit',
      severity: denial.observed_body_bytes > expectedLimit * 2 ? 'high' : 'medium',
      explanation: `The request payload size of ${formatBytes(denial.observed_body_bytes)} exceeded the maximum allowed body size limit.`,
      impact: 'Large payloads can cause memory pressure and processing delays. Request was rejected.',
      recommendations: [
        'Split large batches into smaller chunks',
        'Enable compression (gzip/snappy) if not already used',
        'Remove unnecessary labels or reduce metric cardinality',
        'Implement client-side payload size monitoring'
      ],
      limit_info: {
        type: 'Body Size',
        current_limit: expectedLimit,
        observed_value: denial.observed_body_bytes,
        utilization_percent: (denial.observed_body_bytes / expectedLimit) * 100
      }
    };
  }
  
  if (reason.includes('series') || reason.includes('cardinality')) {
    const expectedLimit = 100;
    return {
      category: 'Cardinality Control',
      severity: 'high',
      explanation: 'The request contained too many unique time series, which can lead to cardinality explosion and system instability.',
      impact: 'High cardinality can degrade query performance and increase storage costs significantly.',
      recommendations: [
        'Review metric labels and remove unnecessary high-cardinality labels',
        'Use label value aggregation or sampling',
        'Implement metric naming conventions to control cardinality',
        'Monitor cardinality growth over time'
      ],
      limit_info: {
        type: 'Series per Request',
        current_limit: expectedLimit,
        observed_value: denial.observed_series || 0,
        utilization_percent: ((denial.observed_series || 0) / expectedLimit) * 100
      }
    };
  }
  
  if (reason.includes('labels')) {
    const expectedLimit = 30;
    return {
      category: 'Label Limits',
      severity: 'medium',
      explanation: 'The request contained metrics with too many labels per series, exceeding the configured limit.',
      impact: 'Excessive labels can impact query performance and storage efficiency.',
      recommendations: [
        'Reduce the number of labels per metric',
        'Combine related labels into fewer, more meaningful labels',
        'Use consistent label naming conventions',
        'Consider using metric hierarchies instead of many labels'
      ],
      limit_info: {
        type: 'Labels per Series',
        current_limit: expectedLimit,
        observed_value: denial.observed_labels || 0,
        utilization_percent: ((denial.observed_labels || 0) / expectedLimit) * 100
      }
    };
  }
  
  // Default analysis for unknown reasons
  return {
    category: 'Other',
    severity: 'low',
    explanation: 'The request was denied for a reason not specifically categorized. Check the exact reason for more details.',
    impact: 'Request processing was interrupted, data may not have been ingested.',
    recommendations: [
      'Review the exact denial reason for specific guidance',
      'Check system logs for additional context',
      'Verify client configuration and payload format',
      'Contact support if the issue persists'
    ]
  };
}

// Get severity color for UI
function getSeverityColor(severity: string): string {
  switch (severity) {
    case 'critical': return 'bg-red-100 text-red-800 border-red-300';
    case 'high': return 'bg-orange-100 text-orange-800 border-orange-300';
    case 'medium': return 'bg-yellow-100 text-yellow-800 border-yellow-300';
    case 'low': return 'bg-blue-100 text-blue-800 border-blue-300';
    default: return 'bg-gray-100 text-gray-800 border-gray-300';
  }
}

// Get category icon
function getCategoryIcon(category: string) {
  switch (category.toLowerCase()) {
    case 'rate limiting': return <TrendingUp className="w-4 h-4" />;
    case 'payload size limit': return <FileText className="w-4 h-4" />;
    case 'cardinality control': return <BarChart3 className="w-4 h-4" />;
    case 'label limits': return <Zap className="w-4 h-4" />;
    case 'data format error': return <AlertCircle className="w-4 h-4" />;
    default: return <Info className="w-4 h-4" />;
  }
}

// Format labels for display
function formatLabels(labels: Record<string, string>): string {
  return Object.entries(labels)
    .filter(([key]) => key !== '__name__') // Exclude metric name from labels
    .map(([key, value]) => `${key}="${value}"`)
    .join(', ');
}

// Format metric with labels
function formatMetricName(sampleMetric: SampleMetric): string {
  const labelsStr = formatLabels(sampleMetric.labels);
  return labelsStr ? `${sampleMetric.metric_name}{${labelsStr}}` : sampleMetric.metric_name;
}

// API function
async function fetchDenials(timeRange: string, tenant: string): Promise<{ denials: DenialDetail[] }> {
  const params = new URLSearchParams({
    since: timeRange,
    ...(tenant && { tenant })
  });
  
  const response = await fetch(`/api/denials?${params}`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  
  const data = await response.json();
  return { denials: data.denials || [] };
}

export function Denials() {
  const [timeRange, setTimeRange] = useState('1h');
  const [selectedTenant, setSelectedTenant] = useState('');
  const [viewMode, setViewMode] = useState<'simple' | 'detailed'>('detailed');
  const [reasonFilter, setReasonFilter] = useState<string>('');

  // Single, simple query
  const { 
    data, 
    isLoading, 
    error, 
    refetch 
  } = useQuery({
    queryKey: ['denials', timeRange, selectedTenant],
    queryFn: () => fetchDenials(timeRange, selectedTenant),
    refetchInterval: 30000, // 30 seconds
    staleTime: 15000, // 15 seconds
    retry: 2
  });

  const denials = data?.denials || [];

  // Unique reasons for filter select
  const uniqueReasons = React.useMemo(
    () => Array.from(new Set(denials.map((d) => d.reason))).sort(),
    [denials]
  );

  // Apply client-side filtering by reason
  const filteredDenials = React.useMemo(() => {
    if (!reasonFilter) return denials;
    return denials.filter((d) => d.reason === reasonFilter);
  }, [denials, reasonFilter]);

  // Show only first 50 for performance
  const displayedDenials = filteredDenials.slice(0, 50);
  const hasMore = filteredDenials.length > 50;

  // Early returns for different states
  if (isLoading) {
    return (
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col space-y-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Recent Denials</h1>
            <p className="text-gray-600 mt-1">Monitor request denials and rate limiting</p>
          </div>
          
          <div className="flex items-center space-x-4">
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
            </select>

            {/* Tenant Filter */}
            <input
              type="text"
              placeholder="Filter by tenant..."
              value={selectedTenant}
              onChange={(e) => setSelectedTenant(e.target.value)}
              className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />

            {/* Refresh Button */}
            <button
              onClick={() => refetch()}
              disabled={isLoading}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 text-sm"
            >
              <Loader className="w-4 h-4 animate-spin" />
            </button>
          </div>
        </div>

        <Card className="p-8 text-center">
          <Loader className="w-8 h-8 animate-spin mx-auto mb-4 text-blue-500" />
          <p className="text-gray-600">Loading denials...</p>
        </Card>
      </div>
    );
  }

  if (error) {
    return (
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col space-y-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Recent Denials</h1>
            <p className="text-gray-600 mt-1">Monitor request denials and rate limiting</p>
          </div>
          
          <div className="flex items-center space-x-4">
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
            </select>

            {/* Tenant Filter */}
            <input
              type="text"
              placeholder="Filter by tenant..."
              value={selectedTenant}
              onChange={(e) => setSelectedTenant(e.target.value)}
              className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />

            {/* Refresh Button */}
            <button
              onClick={() => refetch()}
              disabled={isLoading}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 text-sm"
            >
              Refresh
            </button>
          </div>
        </div>

        <Card className="p-8 text-center border-red-200">
          <AlertTriangle className="w-8 h-8 mx-auto mb-4 text-red-500" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">Failed to load denials</h3>
          <p className="text-red-600 mb-4">{error instanceof Error ? error.message : 'Unknown error occurred'}</p>
          <button
            onClick={() => refetch()}
            className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
          >
            Try Again
          </button>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col space-y-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Recent Denials</h1>
          <p className="text-gray-600 mt-1">Monitor request denials and rate limiting</p>
        </div>
        
        <div className="flex items-center space-x-4">
          {/* View Mode Toggle */}
          <div className="flex items-center space-x-2 bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setViewMode('detailed')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                viewMode === 'detailed' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <Info className="w-4 h-4 mr-1 inline" />
              Detailed
            </button>
            <button
              onClick={() => setViewMode('simple')}
              className={`px-3 py-1 text-sm font-medium rounded-md transition-colors ${
                viewMode === 'simple' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              <FileText className="w-4 h-4 mr-1 inline" />
              Simple
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
          </select>

          {/* Tenant Filter */}
          <input
            type="text"
            placeholder="Filter by tenant (e.g., ui-test)..."
            value={selectedTenant}
            onChange={(e) => setSelectedTenant(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-48"
          />

          {/* Reason Filter */}
          <select
            value={reasonFilter}
            onChange={(e) => setReasonFilter(e.target.value)}
            className="border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            title="Filter by denial reason"
          >
            <option value="">All reasons</option>
            {uniqueReasons.map((r) => (
              <option key={r} value={r}>{r}</option>
            ))}
          </select>

          {/* Refresh Button */}
          <button
            onClick={() => refetch()}
            disabled={isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 text-sm"
          >
            {isLoading ? <Loader className="w-4 h-4 animate-spin" /> : 'Refresh'}
          </button>
        </div>
      </div>

      {/* Summary */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Found {filteredDenials.length} denials in the last {timeRange}
          {hasMore && ' (showing first 50)'}
        </p>
        <div className="flex items-center space-x-2 text-sm text-gray-500">
          <Clock className="w-4 h-4" />
          <span>Last updated: {new Date().toLocaleTimeString()}</span>
        </div>
      </div>

                {/* Empty State */}
          {filteredDenials.length === 0 ? (
            <Card className="p-8 text-center">
              <CheckCircle className="w-12 h-12 text-green-500 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No Denials Found</h3>
              <p className="text-gray-600">All requests are being processed successfully.</p>
            </Card>
          ) : viewMode === 'detailed' ? (
            /* Detailed Cards View */
            <div className="space-y-6">
              {hasMore && (
                <div className="bg-yellow-50 p-3 rounded-lg">
                  <p className="text-sm text-yellow-800">
                    Showing first 50 of {filteredDenials.length} denials. Use filters to narrow results.
                  </p>
                </div>
              )}
              
              {displayedDenials.map((denial, index) => {
                const analysis = analyzeDenial(denial);
                return (
                  <Card key={index} className="p-6 border-l-4 border-l-red-400">
                    <div className="space-y-4">
                      {/* Header */}
                      <div className="flex items-start justify-between">
                        <div className="flex items-center space-x-3">
                          <span className="font-mono text-sm bg-gray-100 px-2 py-1 rounded">
                            {denial.tenant_id}
                          </span>
                          <Badge className={`${getSeverityColor(analysis.severity)} border`}>
                            {analysis.severity.toUpperCase()}
                          </Badge>
                          <div className="flex items-center space-x-1 text-gray-600">
                            {getCategoryIcon(analysis.category)}
                            <span className="text-sm font-medium">{analysis.category}</span>
                          </div>
                        </div>
                        <div className="text-right text-sm text-gray-500">
                          <div>{new Date(denial.timestamp).toLocaleString()}</div>
                          <div>{getRelativeTime(denial.timestamp)}</div>
                        </div>
                      </div>

                      {/* Denial Reason */}
                      <div className="bg-red-50 p-3 rounded-lg">
                        <Badge variant="outline" className="text-red-700 border-red-300 mb-2">
                          {denial.reason}
                        </Badge>
                        <p className="text-sm text-red-800">{analysis.explanation}</p>
                      </div>

                      {/* Metrics Grid */}
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div className="bg-blue-50 p-3 rounded-lg">
                          <div className="font-medium text-blue-700">Observed Samples</div>
                          <div className="font-mono text-lg text-blue-900">{denial.observed_samples.toLocaleString()}</div>
                        </div>
                        <div className="bg-purple-50 p-3 rounded-lg">
                          <div className="font-medium text-purple-700">Body Size</div>
                          <div className="font-mono text-lg text-purple-900">{formatBytes(denial.observed_body_bytes)}</div>
                        </div>
                        {denial.observed_series && (
                          <div className="bg-green-50 p-3 rounded-lg">
                            <div className="font-medium text-green-700">Series Count</div>
                            <div className="font-mono text-lg text-green-900">{denial.observed_series.toLocaleString()}</div>
                          </div>
                        )}
                        {denial.observed_labels && (
                          <div className="bg-orange-50 p-3 rounded-lg">
                            <div className="font-medium text-orange-700">Labels Count</div>
                            <div className="font-mono text-lg text-orange-900">{denial.observed_labels.toLocaleString()}</div>
                          </div>
                        )}
                      </div>

                      {/* Limit Information */}
                      {analysis.limit_info && (
                        <div className="bg-gray-50 p-4 rounded-lg">
                          <h4 className="font-medium text-gray-900 mb-2">Limit Analysis</h4>
                          <div className="grid grid-cols-3 gap-4 text-sm">
                            <div>
                              <div className="text-gray-600">Type</div>
                              <div className="font-medium">{analysis.limit_info.type}</div>
                            </div>
                            <div>
                              <div className="text-gray-600">Current Limit</div>
                              <div className="font-mono">
                                {analysis.limit_info.type.includes('Body') 
                                  ? formatBytes(analysis.limit_info.current_limit)
                                  : analysis.limit_info.current_limit.toLocaleString()
                                }
                              </div>
                            </div>
                            <div>
                              <div className="text-gray-600">Utilization</div>
                              <div className={`font-medium ${
                                analysis.limit_info.utilization_percent > 100 ? 'text-red-600' : 
                                analysis.limit_info.utilization_percent > 80 ? 'text-orange-600' : 'text-green-600'
                              }`}>
                                {analysis.limit_info.utilization_percent.toFixed(1)}%
                              </div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* Impact & Recommendations */}
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div className="bg-orange-50 p-4 rounded-lg">
                          <h4 className="font-medium text-orange-900 mb-2 flex items-center">
                            <AlertTriangle className="w-4 h-4 mr-1" />
                            Impact
                          </h4>
                          <p className="text-sm text-orange-800">{analysis.impact}</p>
                        </div>
                        <div className="bg-blue-50 p-4 rounded-lg">
                          <h4 className="font-medium text-blue-900 mb-2 flex items-center">
                            <CheckCircle className="w-4 h-4 mr-1" />
                            Recommendations
                          </h4>
                          <ul className="space-y-1 text-sm text-blue-800">
                            {analysis.recommendations.slice(0, 2).map((rec, idx) => (
                              <li key={idx} className="flex items-start">
                                <span className="text-blue-600 mr-1">•</span>
                                <span>{rec}</span>
                              </li>
                            ))}
                            {analysis.recommendations.length > 2 && (
                              <li className="text-blue-600 text-xs">
                                +{analysis.recommendations.length - 2} more recommendations
                              </li>
                            )}
                          </ul>
                        </div>
                      </div>

                      {/* Sample Metrics - Only show when real metrics are available */}
                      {denial.sample_metrics && denial.sample_metrics.length > 0 && (
                        <div className="bg-gray-50 p-4 rounded-lg">
                          <h4 className="font-medium text-gray-900 mb-3 flex items-center">
                            <BarChart3 className="w-4 h-4 mr-2" />
                            Sample Metrics That Were Denied
                            <Badge variant="outline" className="ml-2 text-xs">
                              {denial.sample_metrics.length} metric{denial.sample_metrics.length !== 1 ? 's' : ''}
                            </Badge>
                          </h4>
                          <div className="space-y-3">
                            {denial.sample_metrics.slice(0, 5).map((metric, idx) => (
                              <div key={idx} className="bg-white p-3 rounded border">
                                <div className="flex items-start justify-between mb-2">
                                  <div className="flex-1 min-w-0">
                                    <div className="font-mono text-sm text-gray-900 break-all">
                                      <span className="font-medium text-blue-600">{metric.metric_name}</span>
                                      {Object.keys(metric.labels).filter(k => k !== '__name__').length > 0 && (
                                        <span className="text-gray-600">
                                          {'{'}
                                          {Object.entries(metric.labels)
                                            .filter(([key]) => key !== '__name__')
                                            .map(([key, value], labelIdx, arr) => (
                                              <span key={key}>
                                                <span className="text-purple-600">{key}</span>
                                                <span className="text-gray-400">="</span>
                                                <span className="text-green-600">{value}</span>
                                                <span className="text-gray-400">"</span>
                                                {labelIdx < arr.length - 1 && <span className="text-gray-400">, </span>}
                                              </span>
                                            ))
                                          }
                                          {'}'}
                                        </span>
                                      )}
                                    </div>
                                  </div>
                                  <div className="flex flex-col items-end text-sm ml-4">
                                    <div className="font-mono font-medium text-gray-900">
                                      {metric.value.toLocaleString()}
                                    </div>
                                    <div className="text-xs text-gray-500">
                                      {new Date(metric.timestamp).toLocaleTimeString()}
                                    </div>
                                  </div>
                                </div>
                                
                                {/* Labels breakdown for better readability */}
                                {Object.keys(metric.labels).filter(k => k !== '__name__').length > 3 && (
                                  <div className="pt-2 border-t border-gray-100">
                                    <div className="text-xs text-gray-600 mb-1">Labels:</div>
                                    <div className="flex flex-wrap gap-1">
                                      {Object.entries(metric.labels)
                                        .filter(([key]) => key !== '__name__')
                                        .map(([key, value]) => (
                                          <span key={key} className="inline-flex items-center px-2 py-1 bg-gray-100 text-xs rounded">
                                            <span className="text-purple-600">{key}</span>
                                            <span className="text-gray-400 mx-1">=</span>
                                            <span className="text-green-600">{value}</span>
                                          </span>
                                        ))
                                      }
                                    </div>
                                  </div>
                                )}
                              </div>
                            ))}
                            
                            {denial.sample_metrics.length > 5 && (
                              <div className="text-center py-2">
                                <span className="text-sm text-gray-500">
                                  and {denial.sample_metrics.length - 5} more metrics...
                                </span>
                              </div>
                            )}
                          </div>
                          
                          <div className="mt-3 text-xs text-gray-600 bg-white p-2 rounded border">
                            <strong>Note:</strong> These are the actual metrics that were denied in this request. 
                            They show the exact metric names, labels, values, and timestamps that exceeded your configured limits.
                          </div>
                        </div>
                      )}
                    </div>
                  </Card>
                );
              })}
            </div>
          ) : (
            /* Simple Table View */
            <Card className="overflow-hidden">
              {hasMore && (
                <div className="bg-yellow-50 p-3 border-b">
                  <p className="text-sm text-yellow-800">
                    Showing first 50 of {filteredDenials.length} denials. Use filters to narrow results.
                  </p>
                </div>
              )}
              
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Time</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Tenant</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Category</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Reason</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Samples</th>
                      <th className="text-left py-3 px-4 font-medium text-gray-900">Body Size</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200">
                    {displayedDenials.map((denial, index) => {
                      const analysis = analyzeDenial(denial);
                      return (
                        <tr key={index} className="hover:bg-gray-50">
                          <td className="py-3 px-4 text-sm">
                            <div className="font-mono text-gray-900 text-xs">
                              {new Date(denial.timestamp).toLocaleString()}
                            </div>
                            <div className="text-xs text-gray-500">
                              {getRelativeTime(denial.timestamp)}
                            </div>
                          </td>
                          <td className="py-3 px-4">
                            <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                              {denial.tenant_id}
                            </span>
                          </td>
                          <td className="py-3 px-4">
                            <div className="flex items-center space-x-1">
                              {getCategoryIcon(analysis.category)}
                              <span className="text-xs text-gray-600">{analysis.category}</span>
                            </div>
                            <Badge className={`${getSeverityColor(analysis.severity)} text-xs mt-1`}>
                              {analysis.severity}
                            </Badge>
                          </td>
                          <td className="py-3 px-4">
                            <Badge 
                              variant="outline" 
                              className="text-red-700 border-red-300 text-xs"
                            >
                              {denial.reason}
                            </Badge>
                          </td>
                          <td className="py-3 px-4 font-mono text-sm">
                            {denial.observed_samples?.toLocaleString() || '0'}
                          </td>
                          <td className="py-3 px-4 font-mono text-sm">
                            {formatBytes(denial.observed_body_bytes || 0)}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </Card>
          )}
    </div>
  );
}