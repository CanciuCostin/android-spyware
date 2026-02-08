import React, { useRef } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { heatmapOptions, exportChart } from '../../utils/chartConfig';

interface HeatmapData {
  name: string; // Hour (0-23)
  data: number[]; // Values for each day
}

interface KeylogHeatmapProps {
  data: HeatmapData[];
  title?: string;
  height?: number;
  enableExport?: boolean;
  onCellClick?: (hour: number, day: number, value: number) => void;
}

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export const KeylogHeatmap: React.FC<KeylogHeatmapProps> = ({
  data,
  title = 'Keylog Activity Heatmap',
  height = 350,
  enableExport = true,
  onCellClick,
}) => {
  const chartRef = useRef<any>(null);

  const options: ApexOptions = {
    ...heatmapOptions,
    chart: {
      ...heatmapOptions.chart,
      id: 'keylog-heatmap',
      events: onCellClick
        ? {
            dataPointSelection: (_event: any, _chartContext: any, config: any) => {
              const hour = parseInt(data[config.seriesIndex]?.name || '0');
              const day = config.dataPointIndex;
              const value = data[config.seriesIndex]?.data[day] || 0;
              onCellClick(hour, day, value);
            },
          }
        : undefined,
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
    xaxis: {
      categories: DAYS,
      labels: {
        style: {
          colors: '#9ca3af',
        },
      },
    },
    yaxis: {
      labels: {
        style: {
          colors: '#9ca3af',
        },
      },
    },
    tooltip: {
      ...heatmapOptions.tooltip,
      custom: ({ seriesIndex, dataPointIndex, w }: any) => {
        const value = w.globals.series[seriesIndex][dataPointIndex];
        const hour = w.globals.labels[seriesIndex];
        const day = DAYS[dataPointIndex];
        return `
          <div class="bg-gray-900 p-3 rounded shadow-lg border border-gray-700">
            <div class="text-sm font-semibold text-gray-200">${day} at ${hour}:00</div>
            <div class="text-xs text-gray-400 mt-1">${value} keystrokes</div>
          </div>
        `;
      },
    },
  };

  const handleExport = (format: 'png' | 'svg' | 'csv') => {
    if (chartRef.current) {
      exportChart(chartRef.current, 'keylog-heatmap', format);
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
        series={data}
        type="heatmap"
        height={height}
      />
    </div>
  );
};
