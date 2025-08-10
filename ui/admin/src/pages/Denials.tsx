
import { useQuery } from '@tanstack/react-query';

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

interface Denial {
  tenant_id: string;
  reason: string;
  timestamp: string;
  observed_samples: number;
  observed_body_bytes: number;
}

export function Denials() {
  const { data, isLoading, error } = useQuery({ 
    queryKey: ['denials'], 
    queryFn: fetchDenials,
    refetchInterval: 5000, // Auto-refresh every 5 seconds
    refetchIntervalInBackground: true
  });
  if (isLoading) return <div className="flex items-center justify-center h-64"><div className="text-lg text-gray-600">Loading denials...</div></div>;
  if (error) return <div className="flex items-center justify-center h-64"><div className="text-lg text-red-600">Failed to load denials: {error instanceof Error ? error.message : 'Unknown error'}</div></div>;
  
  const denials: Denial[] = data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Recent Denials</h1>
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">Auto-refresh (5s)</span>
          </div>
          <div className="text-sm text-gray-500">
            Count: {denials.length}
          </div>
        </div>
      </div>
      
      {denials.length === 0 ? (
        <div className="flex items-center justify-center h-64 bg-gray-50 rounded-lg">
          <div className="text-center">
            <div className="text-lg text-gray-600 mb-2">No recent denials</div>
            <div className="text-sm text-gray-500">
              All requests are being allowed or no traffic is being processed
            </div>
          </div>
        </div>
      ) : (
        <div className="bg-white shadow rounded-lg overflow-hidden">
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
                      <span className="inline-flex items-center px-2 py-1 text-xs font-medium bg-red-100 text-red-800 rounded">
                        {denial.reason}
                      </span>
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
        </div>
      )}
    </div>
  );
}

async function fetchDenials() {
  const res = await fetch(`/api/denials?since=1h&tenant=*`);
  if (!res.ok) throw new Error('failed');
  const data = await res.json();
  // Backend returns {denials: [...]}, extract the denials array
  return data.denials || [];
}


