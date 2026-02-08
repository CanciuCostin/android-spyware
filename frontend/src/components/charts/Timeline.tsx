import React, { useRef, useState } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { defaultChartOptions, exportChart, colorPalettes } from '../../utils/chartConfig';

interface TimelineEvent {
  x: string; // Track name (SMS, Calls, Locations, etc.)
  y: [number, number]; // [start timestamp, end timestamp]
  fillColor?: string;
  label?: string;
}

interface TimelineProps {
  data: TimelineEvent[];
  title?: string;
  height?: number;
  enableExport?: boolean;
  onEventClick?: (event: TimelineEvent) => void;
}

const TRACK_COLORS: Record<string, string> = {
  SMS: colorPalettes.primary[0],
  Calls: colorPalettes.primary[1],
  Locations: colorPalettes.primary[2],
  Apps: colorPalettes.primary[3],
  Photos: colorPalettes.primary[4],
  Commands: colorPalettes.primary[5],
};

export const Timeline: React.FC<TimelineProps> = ({
  data,
  title = 'Event Timeline',
  height = 350,
  enableExport = true,
  onEventClick,
}) => {
  const chartRef = useRef<any>(null);
  const [selectedEvent, setSelectedEvent] = useState<TimelineEvent | null>(null);

  const series = [
    {
      name: 'Events',
      data: data.map(event => ({
        ...event,
        fillColor: event.fillColor || TRACK_COLORS[event.x] || colorPalettes.neutral[0],
      })),
    },
  ];

  const options: ApexOptions = {
    ...defaultChartOptions,
    chart: {
      ...defaultChartOptions.chart,
      type: 'rangeBar',
      id: 'timeline',
      events: onEventClick
        ? {
            dataPointSelection: (_event: any, _chartContext: any, config: any) => {
              const event = data[config.dataPointIndex];
              setSelectedEvent(event);
              onEventClick(event);
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
    plotOptions: {
      bar: {
        horizontal: true,
        rangeBarGroupRows: true,
        barHeight: '80%',
      },
    },
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
      labels: {
        style: {
          colors: '#9ca3af',
        },
      },
    },
    tooltip: {
      ...defaultChartOptions.tooltip,
      custom: ({ dataPointIndex }: any) => {
        const event = data[dataPointIndex];
        const start = new Date(event.y[0]).toLocaleString();
        const end = new Date(event.y[1]).toLocaleString();
        const duration = ((event.y[1] - event.y[0]) / 1000 / 60).toFixed(1);

        return `
          <div class="bg-gray-900 p-3 rounded shadow-lg border border-gray-700">
            <div class="text-sm font-semibold text-gray-200">${event.x}</div>
            ${event.label ? `<div class="text-xs text-gray-300 mt-1">${event.label}</div>` : ''}
            <div class="text-xs text-gray-400 mt-2">
              <div>Start: ${start}</div>
              <div>End: ${end}</div>
              <div>Duration: ${duration} min</div>
            </div>
          </div>
        `;
      },
    },
    legend: {
      show: false,
    },
  };

  const handleExport = (format: 'png' | 'svg' | 'csv') => {
    if (chartRef.current) {
      exportChart(chartRef.current, 'timeline', format);
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
        type="rangeBar"
        height={height}
      />
      {selectedEvent && (
        <div className="mt-4 p-3 bg-gray-700 rounded border border-gray-600">
          <h4 className="text-sm font-semibold mb-2">Selected Event</h4>
          <p className="text-xs text-gray-300">Track: {selectedEvent.x}</p>
          {selectedEvent.label && (
            <p className="text-xs text-gray-300">Label: {selectedEvent.label}</p>
          )}
        </div>
      )}
    </div>
  );
};
