import { useEffect } from 'react';
import { useLayoutStore } from '../stores/layoutStore';
import { Breadcrumbs } from '../components/layout';
import { Terminal } from 'lucide-react';

export function CommandsPage() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);

  useEffect(() => {
    setBreadcrumbs([{ label: 'Commands' }]);
  }, [setBreadcrumbs]);

  return (
    <div className="space-y-6">
      <div>
        <Breadcrumbs items={[{ label: 'Commands' }]} />
        <h1 className="text-3xl font-bold text-gray-900 mt-2">Commands</h1>
        <p className="text-gray-600 mt-1">Execute and manage device commands</p>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        <div className="p-6">
          <div className="text-center py-12">
            <Terminal size={48} className="mx-auto text-gray-400 mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">Command Center</h3>
            <p className="text-gray-600">Select a device to start executing commands</p>
          </div>
        </div>
      </div>
    </div>
  );
}
