import React, { useRef } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { donutOptions, exportChart, colorPalettes } from '../../utils/chartConfig';

interface AppUsageData {
  name: string;
  value: number;
  color?: string;
}

interface AppUsageDonutProps {
  data: AppUsageData[];
  title?: string;
  height?: number;
  enableExport?: boolean;
  onSliceClick?: (appName: string, value: number) => void;
}

export const AppUsageDonut: React.FC<AppUsageDonutProps> = ({
  data,
  title = 'App Usage Distribution',
  height = 350,
  enableExport = true,
  onSliceClick,
}) => {
  const chartRef = useRef<any>(null);

  const series = data.map(d => d.value);
  const labels = data.map(d => d.name);
  const colors = data.map((d, i) => d.color || colorPalettes.primary[i % colorPalettes.primary.length]);

  const options: ApexOptions = {
    ...donutOptions,
    chart: {
      ...donutOptions.chart,
      id: 'app-usage-donut',
      events: onSliceClick
        ? {
            dataPointSelection: (_event: any, _chartContext: any, config: any) => {
              const appName = labels[config.dataPointIndex];
              const value = series[config.dataPointIndex];
              onSliceClick(appName, value);
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
    labels,
    colors,
    tooltip: {
      ...donutOptions.tooltip,
      y: {
        formatter: (val: number) => `${val.toFixed(0)} minutes`,
      },
    },
    plotOptions: {
      pie: {
        ...donutOptions.plotOptions?.pie,
        donut: {
          ...donutOptions.plotOptions?.pie?.donut,
          labels: {
            show: true,
            total: {
              show: true,
              showAlways: true,
              label: 'Total Usage',
              fontSize: '14px',
              fontWeight: 600,
              color: '#e5e7eb',
              formatter: (w: any) => {
                const total = w.globals.seriesTotals.reduce((a: number, b: number) => a + b, 0);
                return `${(total / 60).toFixed(1)}h`;
              },
            },
          },
        },
      },
    },
  };

  const handleExport = (format: 'png' | 'svg' | 'csv') => {
    if (chartRef.current) {
      exportChart(chartRef.current, 'app-usage', format);
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
        type="donut"
        height={height}
      />
    </div>
  );
};
