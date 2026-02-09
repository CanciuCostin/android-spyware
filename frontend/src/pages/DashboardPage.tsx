import { useEffect } from 'react';
import { useLayoutStore } from '../stores/layoutStore';
import { Breadcrumbs } from '../components/layout';
import { Activity, Smartphone, Terminal, AlertCircle } from 'lucide-react';

export function DashboardPage() {
  const setBreadcrumbs = useLayoutStore((state) => state.setBreadcrumbs);

  useEffect(() => {
    setBreadcrumbs([{ label: 'Dashboard' }]);
  }, [setBreadcrumbs]);

  return (
    <div className="space-y-6">
      <div>
        <Breadcrumbs items={[{ label: 'Dashboard' }]} />
        <h1 className="text-3xl font-bold text-gray-900 mt-2">Dashboard</h1>
        <p className="text-gray-600 mt-1">Monitor and manage your connected devices</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Devices</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">12</p>
            </div>
            <div className="w-12 h-12 bg-cyan-100 rounded-lg flex items-center justify-center">
              <Smartphone className="text-cyan-600" size={24} />
            </div>
          </div>
          <p className="text-xs text-green-600 mt-3">↑ 3 new this week</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Active Devices</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">8</p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <Activity className="text-green-600" size={24} />
            </div>
          </div>
          <p className="text-xs text-gray-500 mt-3">66.7% online</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Commands Run</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">247</p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <Terminal className="text-blue-600" size={24} />
            </div>
          </div>
          <p className="text-xs text-gray-500 mt-3">Last 24 hours</p>
        </div>

        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Alerts</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">3</p>
            </div>
            <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center">
              <AlertCircle className="text-red-600" size={24} />
            </div>
          </div>
          <p className="text-xs text-red-600 mt-3">2 require attention</p>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Recent Activity</h2>
        </div>
        <div className="p-6">
          <div className="text-gray-500 text-center py-8">
            No recent activity to display
          </div>
        </div>
      </div>
    </div>
  );
}
