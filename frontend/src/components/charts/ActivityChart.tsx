import React, { useRef, useEffect, useState } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { barChartOptions, exportChart, colorPalettes } from '../../utils/chartConfig';

interface ActivityData {
  name: string;
  data: { x: number; y: number }[]; // x: timestamp, y: count
}

interface ActivityChartProps {
  series: ActivityData[];
  title?: string;
  height?: number;
  enableExport?: boolean;
  realtimeUpdate?: boolean;
  updateInterval?: number; // ms
}

export const ActivityChart: React.FC<ActivityChartProps> = ({
  series: initialSeries,
  title = 'Device Activity',
  height = 350,
  enableExport = true,
  realtimeUpdate = false,
  updateInterval = 5000,
}) => {
  const chartRef = useRef<any>(null);
  const [series, setSeries] = useState<ActivityData[]>(initialSeries);

  useEffect(() => {
    if (!realtimeUpdate) {
      setSeries(initialSeries);
      return;
    }

    const interval = setInterval(() => {
      setSeries(prev =>
        prev.map(s => ({
          ...s,
          data: [
            ...s.data.slice(-50), // Keep last 50 points
            {
              x: Date.now(),
              y: Math.floor(Math.random() * 10), // Simulated data
            },
          ],
        }))
      );
    }, updateInterval);

    return () => clearInterval(interval);
  }, [realtimeUpdate, updateInterval, initialSeries]);

  const colors = series.map((_, i) => colorPalettes.primary[i % colorPalettes.primary.length]);

  const options: ApexOptions = {
    ...barChartOptions,
    chart: {
      ...barChartOptions.chart,
      id: 'activity-chart',
      animations: {
        enabled: !realtimeUpdate,
        dynamicAnimation: {
          enabled: realtimeUpdate,
          speed: 350,
        },
      },
    },
    title: {
      text: title,
      align: 'left',
      style: {
        fontSize: '16px',
        fontWeight: 600,
        color: '#f9fafb',
      },
    },
    colors,
    xaxis: {
      type: 'datetime',
      labels: {
        style: {
          colors: '#9ca3af',
        },
        datetimeFormatter: {
          year: 'yyyy',
          month: 'MMM \'yy',
          day: 'dd MMM',
          hour: 'HH:mm',
        },
      },
    },
    yaxis: {
      title: {
        text: 'Count',
        style: {
          color: '#9ca3af',
        },
      },
      labels: {
        style: {
          colors: '#9ca3af',
        },
      },
    },
    tooltip: {
      ...barChartOptions.tooltip,
      x: {
        format: 'dd MMM yyyy HH:mm',
      },
    },
    legend: {
      ...barChartOptions.legend,
      position: 'top',
      horizontalAlign: 'right',
    },
  };

  const handleExport = (format: 'png' | 'svg' | 'csv') => {
    if (chartRef.current) {
      exportChart(chartRef.current, 'activity', format);
    }
  };

  return (
    <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
      {enableExport && (
        <div className="flex justify-end gap-2 mb-2">
          <button
            onClick={() => handleExport('png')}
            className="px-3 py-1 text-xs bg-gray-700 hover:bg-gray-600 rounded transition"
          >
            PNG
          </button>
          <button
            onClick={() => handleExport('svg')}
            className="px-3 py-1 text-xs bg-gray-700 hover:bg-gray-600 rounded transition"
          >
            SVG
          </button>
          <button
            onClick={() => handleExport('csv')}
            className="px-3 py-1 text-xs bg-gray-700 hover:bg-gray-600 rounded transition"
          >
            CSV
          </button>
        </div>
      )}
      <Chart
        ref={chartRef}
        options={options}
        series={series}
        type="bar"
        height={height}
      />
    </div>
  );
};
