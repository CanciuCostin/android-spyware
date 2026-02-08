import type { ApexOptions } from 'apexcharts';

export const darkTheme: ApexOptions['theme'] = {
  mode: 'dark',
  palette: 'palette1',
};

export const colorPalettes = {
  primary: ['#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b', '#10b981', '#06b6d4'],
  success: ['#10b981', '#059669', '#047857'],
  warning: ['#f59e0b', '#d97706', '#b45309'],
  danger: ['#ef4444', '#dc2626', '#b91c1c'],
  info: ['#3b82f6', '#2563eb', '#1d4ed8'],
  neutral: ['#6b7280', '#4b5563', '#374151'],
};

export const defaultChartOptions: ApexOptions = {
  theme: darkTheme,
  chart: {
    background: 'transparent',
    foreColor: '#e5e7eb',
    fontFamily: 'Inter, system-ui, sans-serif',
    toolbar: {
      show: true,
      tools: {
        download: true,
        selection: true,
        zoom: true,
        zoomin: true,
        zoomout: true,
        pan: true,
        reset: true,
      },
    },
    animations: {
      enabled: true,
      easing: 'easeinout',
      speed: 400,
    },
  },
  grid: {
    borderColor: '#374151',
    strokeDashArray: 3,
  },
  tooltip: {
    theme: 'dark',
    style: {
      fontSize: '12px',
    },
  },
  legend: {
    position: 'bottom',
    horizontalAlign: 'center',
    fontSize: '12px',
    labels: {
      colors: '#e5e7eb',
    },
  },
  dataLabels: {
    enabled: false,
  },
};

export const timeSeriesOptions: ApexOptions = {
  ...defaultChartOptions,
  chart: {
    ...defaultChartOptions.chart,
    type: 'area',
    zoom: {
      enabled: true,
      type: 'x',
      autoScaleYaxis: true,
    },
  },
  stroke: {
    curve: 'smooth',
    width: 2,
  },
  fill: {
    type: 'gradient',
    gradient: {
      shadeIntensity: 1,
      opacityFrom: 0.7,
      opacityTo: 0.2,
      stops: [0, 90, 100],
    },
  },
  xaxis: {
    type: 'datetime',
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
};

export const heatmapOptions: ApexOptions = {
  ...defaultChartOptions,
  chart: {
    ...defaultChartOptions.chart,
    type: 'heatmap',
  },
  plotOptions: {
    heatmap: {
      shadeIntensity: 0.5,
      colorScale: {
        ranges: [
          { from: 0, to: 10, color: '#1e293b', name: 'low' },
          { from: 11, to: 50, color: '#3b82f6', name: 'medium' },
          { from: 51, to: 100, color: '#8b5cf6', name: 'high' },
          { from: 101, to: 1000, color: '#ec4899', name: 'very high' },
        ],
      },
    },
  },
};

export const donutOptions: ApexOptions = {
  ...defaultChartOptions,
  chart: {
    ...defaultChartOptions.chart,
    type: 'donut',
  },
  plotOptions: {
    pie: {
      donut: {
        size: '65%',
        labels: {
          show: true,
          total: {
            show: true,
            showAlways: true,
            fontSize: '16px',
            fontWeight: 600,
            color: '#e5e7eb',
          },
        },
      },
    },
  },
  dataLabels: {
    enabled: true,
    formatter: (val: number) => `${val.toFixed(1)}%`,
  },
  legend: {
    ...defaultChartOptions.legend,
    position: 'right',
  },
};

export const barChartOptions: ApexOptions = {
  ...defaultChartOptions,
  chart: {
    ...defaultChartOptions.chart,
    type: 'bar',
    stacked: true,
  },
  plotOptions: {
    bar: {
      horizontal: false,
      columnWidth: '70%',
      borderRadius: 4,
    },
  },
  xaxis: {
    type: 'datetime',
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
};

export const exportChart = (chartRef: any, filename: string, format: 'png' | 'svg' | 'csv') => {
  if (!chartRef) return;

  switch (format) {
    case 'png':
      chartRef.dataURI().then((uri: any) => {
        const link = document.createElement('a');
        link.href = uri.imgURI;
        link.download = `${filename}.png`;
        link.click();
      });
      break;
    case 'svg':
      chartRef.dataURI({ scale: 2 }).then((uri: any) => {
        const link = document.createElement('a');
        link.href = uri.imgURI;
        link.download = `${filename}.svg`;
        link.click();
      });
      break;
    case 'csv':
      const data = chartRef.w.config.series;
      const csv = convertToCSV(data);
      downloadCSV(csv, `${filename}.csv`);
      break;
  }
};

const convertToCSV = (data: any[]): string => {
  if (!data || data.length === 0) return '';

  const headers = ['Series', 'Timestamp', 'Value'];
  const rows = data.flatMap((series: any) =>
    (series.data || []).map((point: any) => [
      series.name,
      Array.isArray(point) ? new Date(point[0]).toISOString() : '',
      Array.isArray(point) ? point[1] : point,
    ])
  );

  return [headers, ...rows].map(row => row.join(',')).join('\n');
};

const downloadCSV = (csv: string, filename: string) => {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
};

export const sampleData = (data: any[], maxPoints: number = 100): any[] => {
  if (data.length <= maxPoints) return data;

  const step = Math.ceil(data.length / maxPoints);
  return data.filter((_, index) => index % step === 0);
};

export const formatters = {
  percentage: (val: number) => `${val.toFixed(1)}%`,
  number: (val: number) => val.toLocaleString(),
  bytes: (val: number) => {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = val;
    let unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return `${size.toFixed(2)} ${units[unitIndex]}`;
  },
  duration: (val: number) => {
    const hours = Math.floor(val / 3600);
    const minutes = Math.floor((val % 3600) / 60);
    const seconds = val % 60;
    return `${hours}h ${minutes}m ${seconds}s`;
  },
};
