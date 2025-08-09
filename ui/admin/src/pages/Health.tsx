
import { useQuery } from '@tanstack/react-query';

export function Health() {
  const { data, isLoading, error } = useQuery({ 
    queryKey: ['health'], 
    queryFn: fetchHealth,
    refetchInterval: 10000, // Auto-refresh every 10 seconds
    refetchIntervalInBackground: true
  });
  if (isLoading) return <div className="flex items-center justify-center h-64"><div className="text-lg text-gray-600">Loading health status...</div></div>;
  if (error) return <div className="flex items-center justify-center h-64"><div className="text-lg text-red-600">Failed to load health: {error instanceof Error ? error.message : 'Unknown error'}</div></div>;
  
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">System Health</h1>
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
            <span className="text-sm text-gray-600">Auto-refresh (10s)</span>
          </div>
          <a 
            href="/api/export/csv" 
            className="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            📥 Export CSV
          </a>
        </div>
      </div>
      
      <div className="bg-white shadow rounded-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">RLS Service Status</h3>
        </div>
        <div className="p-6">
          <pre className="bg-gray-50 p-4 rounded-lg border text-sm font-mono overflow-x-auto">
            {JSON.stringify(data, null, 2)}
          </pre>
        </div>
      </div>
    </div>
  );
}

async function fetchHealth() {
  const res = await fetch(`/api/health`);
  if (!res.ok) throw new Error('failed');
  return res.json();
}


