import { useEffect } from 'react';
import { useLayoutStore } from '../stores/layoutStore';
import { Breadcrumbs } from '../components/layout';
import { Settings as SettingsIcon } from 'lucide-react';

export function SettingsPage() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);

  useEffect(() => {
    setBreadcrumbs([{ label: 'Settings' }]);
  }, [setBreadcrumbs]);

  return (
    <div className="space-y-6">
      <div>
        <Breadcrumbs items={[{ label: 'Settings' }]} />
        <h1 className="text-3xl font-bold text-gray-900 mt-2">Settings</h1>
        <p className="text-gray-600 mt-1">Configure your application preferences</p>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">General Settings</h2>
        </div>
        <div className="p-6">
          <div className="text-center py-12">
            <SettingsIcon size={48} className="mx-auto text-gray-400 mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">Settings Panel</h3>
            <p className="text-gray-600">Configuration options will appear here</p>
          </div>
        </div>
      </div>
    </div>
  );
}
