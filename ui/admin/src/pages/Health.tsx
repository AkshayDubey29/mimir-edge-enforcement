
import { useQuery } from '@tanstack/react-query';

export function Health() {
  const { data, isLoading, error } = useQuery({ queryKey: ['health'], queryFn: fetchHealth });
  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Failed to load health</div>;
  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">System Health</h2>
      <pre className="bg-gray-50 p-3 rounded border text-sm">{JSON.stringify(data, null, 2)}</pre>
      <a href="/api/export/csv" className="inline-block mt-4 px-3 py-2 border rounded bg-white">Export Denials CSV</a>
    </div>
  );
}

async function fetchHealth() {
  const res = await fetch(`/api/health`);
  if (!res.ok) throw new Error('failed');
  return res.json();
}


