import React, { useRef, useState, useEffect } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { timeSeriesOptions, exportChart, sampleData } from '../../utils/chartConfig';

interface TimeSeriesData {
  name: string;
  data: [number, number][]; // [timestamp, value]
}

interface TimeSeriesChartProps {
  series: TimeSeriesData[];
  title?: string;
  height?: number;
  yAxisTitle?: string;
  enableExport?: boolean;
  maxPoints?: number;
  realtimeUpdate?: boolean;
}

export const TimeSeriesChart: React.FC<TimeSeriesChartProps> = ({
  series,
  title,
  height = 350,
  yAxisTitle,
  enableExport = true,
  maxPoints = 100,
  realtimeUpdate = false,
}) => {
  const chartRef = useRef<any>(null);
  const [sampledSeries, setSampledSeries] = useState<TimeSeriesData[]>([]);

  useEffect(() => {
    const sampled = series.map(s => ({
      ...s,
      data: sampleData(s.data, maxPoints),
    }));
    setSampledSeries(sampled);
  }, [series, maxPoints]);

  const options: ApexOptions = {
    ...timeSeriesOptions,
    chart: {
      ...timeSeriesOptions.chart,
      id: title || 'timeseries',
      animations: {
        enabled: !realtimeUpdate,
        dynamicAnimation: {
          enabled: realtimeUpdate,
          speed: 350,
        },
      },
    },
    title: title
      ? {
          text: title,
          align: 'left',
          style: {
            fontSize: '16px',
            fontWeight: 600,
            color: '#f9fafb',
          },
        }
      : undefined,
    yaxis: {
      ...timeSeriesOptions.yaxis,
      title: yAxisTitle
        ? {
            text: yAxisTitle,
            style: {
              color: '#9ca3af',
            },
          }
        : undefined,
    },
    tooltip: {
      ...timeSeriesOptions.tooltip,
      x: {
        format: 'dd MMM yyyy HH:mm',
      },
    },
  };

  const handleExport = (format: 'png' | 'svg' | 'csv') => {
    if (chartRef.current) {
      exportChart(chartRef.current, title || 'timeseries', format);
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
        series={sampledSeries}
        type="area"
        height={height}
      />
    </div>
  );
};
