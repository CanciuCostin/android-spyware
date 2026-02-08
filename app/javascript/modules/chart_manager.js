/**
 * Chart Manager - Chart.js wrapper for EagleSpy V5
 *
 * Lazy-loads Chart.js and provides helpers for creating, updating,
 * and exporting charts used in the device statistics dashboard.
 *
 * @module chart_manager
 */

/**
 * @typedef {Object} ChartDataset
 * @property {string} label
 * @property {number[]} data
 * @property {string} [borderColor]
 * @property {string} [backgroundColor]
 * @property {number} [tension]
 * @property {number} [borderRadius]
 * @property {string} [yAxisID]
 */

/**
 * @typedef {Object} ChartConfig
 * @property {string} type - Chart type ('line', 'bar', 'doughnut', etc.)
 * @property {string[]} labels - X-axis labels
 * @property {ChartDataset[]} datasets
 * @property {Object} [options] - Chart.js options override
 */

/** @type {Map<string, import('chart.js').Chart>} */
const charts = new Map();

/** @type {typeof import('chart.js').Chart|null} */
let ChartConstructor = null;

/**
 * Lazy-load Chart.js and its date adapter.
 * @returns {Promise<typeof import('chart.js').Chart>}
 */
const loadChartJS = async () => {
  if (ChartConstructor) return ChartConstructor;

  const { default: Chart } = await import(/* webpackChunkName: "chartjs" */ 'chart.js/auto');
  await import(/* webpackChunkName: "chartjs" */ 'chartjs-adapter-date-fns');

  Chart.defaults.font.family = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  Chart.defaults.color = '#6b7280';
  Chart.defaults.plugins.legend.display = false;

  ChartConstructor = Chart;
  return Chart;
};

/**
 * Default tooltip configuration shared across charts.
 * @returns {Object}
 */
const defaultTooltip = () => ({
  backgroundColor: 'rgba(0, 0, 0, 0.8)',
  padding: 12,
  titleFont: { size: 14, weight: 'bold' },
  bodyFont: { size: 13 },
  cornerRadius: 8
});

/**
 * Create or replace a chart on a canvas element.
 * @param {string} canvasId - DOM id of the canvas element
 * @param {ChartConfig} config
 * @returns {Promise<import('chart.js').Chart|null>}
 */
export const renderChart = async (canvasId, config) => {
  const Chart = await loadChartJS();
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  // Destroy existing chart on same canvas
  if (charts.has(canvasId)) {
    charts.get(canvasId).destroy();
  }

  const { type, labels, datasets, options = {} } = config;

  const chart = new Chart(ctx, {
    type,
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        tooltip: defaultTooltip(),
        ...options.plugins
      },
      ...options
    }
  });

  charts.set(canvasId, chart);
  return chart;
};

/**
 * Update data on an existing chart without full re-render.
 * @param {string} canvasId
 * @param {string[]} labels
 * @param {Array<number[]>} dataArrays - One array per dataset
 */
export const updateChart = (canvasId, labels, dataArrays) => {
  const chart = charts.get(canvasId);
  if (!chart) return;

  chart.data.labels = labels;
  dataArrays.forEach((data, i) => {
    if (chart.data.datasets[i]) {
      chart.data.datasets[i].data = data;
    }
  });
  chart.update();
};

/**
 * Destroy a chart and free its resources.
 * @param {string} canvasId
 */
export const destroyChart = (canvasId) => {
  const chart = charts.get(canvasId);
  if (chart) {
    chart.destroy();
    charts.delete(canvasId);
  }
};

/**
 * Destroy all managed charts.
 */
export const destroyAll = () => {
  for (const [id, chart] of charts) {
    chart.destroy();
    charts.delete(id);
  }
};

/**
 * Export a chart canvas as a PNG data URL.
 * @param {string} canvasId
 * @returns {Promise<string|null>}
 */
export const exportAsPng = async (canvasId) => {
  const { default: html2canvas } = await import(/* webpackChunkName: "export-utils" */ 'html2canvas');
  const el = document.getElementById(canvasId)?.parentElement;
  if (!el) return null;

  const canvas = await html2canvas(el);
  return canvas.toDataURL();
};

/**
 * Export a chart canvas as a PDF blob download.
 * @param {string} canvasId
 * @param {string} [filename]
 */
export const exportAsPdf = async (canvasId, filename) => {
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
    import(/* webpackChunkName: "export-utils" */ 'html2canvas'),
    import(/* webpackChunkName: "export-utils" */ 'jspdf')
  ]);

  const el = document.getElementById(canvasId)?.parentElement;
  if (!el) return;

  const canvas = await html2canvas(el);
  const imgData = canvas.toDataURL('image/png');
  const orientation = canvas.width > canvas.height ? 'landscape' : 'portrait';
  const pdf = new jsPDF({ orientation });
  const imgWidth = pdf.internal.pageSize.getWidth();
  const imgHeight = (canvas.height * imgWidth) / canvas.width;
  pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
  pdf.save(filename || `${canvasId}-${Date.now()}.pdf`);
};

export default {
  renderChart,
  updateChart,
  destroyChart,
  destroyAll,
  exportAsPng,
  exportAsPdf
};
