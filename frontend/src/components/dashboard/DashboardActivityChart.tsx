import React, { useState, useEffect } from 'react';
import { ActivityChart } from '../charts';

interface DashboardActivityChartProps {
  commandsData?: { x: number; y: number }[];
  dataCollectedPoints?: { x: number; y: number }[];
}

export const DashboardActivityChart: React.FC<DashboardActivityChartProps> = ({
  commandsData,
  dataCollectedPoints,
}) => {
  const [series, setSeries] = useState([
    {
      name: 'Commands',
      data: commandsData || generateDefaultData(),
    },
    {
      name: 'Data Events',
      data: dataCollectedPoints || generateDefaultData(),
    },
  ]);

  useEffect(() => {
    if (commandsData || dataCollectedPoints) {
      setSeries([
        {
          name: 'Commands',
          data: commandsData || generateDefaultData(),
        },
        {
          name: 'Data Events',
          data: dataCollectedPoints || generateDefaultData(),
        },
      ]);
    }
  }, [commandsData, dataCollectedPoints]);

  return (
    <ActivityChart
      series={series}
      title="Recent Activity (24h)"
      height={250}
      realtimeUpdate={false}
      enableExport={false}
    />
  );
};

function generateDefaultData(): { x: number; y: number }[] {
  const now = Date.now();
  const interval = 3600000; // 1 hour
  return Array.from({ length: 12 }, (_, i) => ({
    x: now - (12 - i) * interval,
    y: Math.floor(Math.random() * 20),
  }));
}
