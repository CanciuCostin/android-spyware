import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

/**
 * Keylog Analytics Dashboard
 * Visualizes typing analytics data from the KeylogAnalyticsService API.
 */
class KeylogDashboard {
  constructor() {
    this.charts = {};
    this.deviceId = null;
    this.days = 30;
    this.init();
  }

  init() {
    const deviceSelect = document.getElementById('analytics-device-select');
    if (!deviceSelect) return;

    this.deviceId = deviceSelect.value;
    deviceSelect.addEventListener('change', (e) => {
      this.deviceId = e.target.value;
      this.refresh();
    });

    // Date range buttons
    document.querySelectorAll('.date-range-btn[data-days]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.date-range-btn').forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');
        this.days = parseInt(e.target.dataset.days);
        this.refresh();
      });
    });

    // Granularity selector
    const granSelect = document.getElementById('timeline-granularity');
    if (granSelect) {
      granSelect.addEventListener('change', () => this.refresh());
    }

    // Export buttons
    document.getElementById('export-csv-btn')?.addEventListener('click', () => this.exportReport('csv'));
    document.getElementById('export-json-btn')?.addEventListener('click', () => this.exportReport('json'));

    this.refresh();
  }

  dateParams() {
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - this.days);
    return `start_date=${start.toISOString()}&end_date=${end.toISOString()}`;
  }

  async fetchAnalytics() {
    try {
      const resp = await fetch(`/api/devices/${this.deviceId}/keylog_analytics?${this.dateParams()}`);
      if (resp.status === 403) {
        this.showConsentStatus('denied');
        return null;
      }
      if (!resp.ok) return null;
      const data = await resp.json();
      this.showConsentStatus(data.consent_status === 'granted' ? 'granted' : 'denied');
      return data.analytics;
    } catch (e) {
      console.error('Failed to fetch keylog analytics:', e);
      return null;
    }
  }

  showConsentStatus(status) {
    const banner = document.getElementById('consent-status-banner');
    const text = document.getElementById('consent-status-text');
    if (!banner || !text) return;

    banner.className = `consent-banner ${status}`;
    if (status === 'granted') {
      text.textContent = '✅ Data collection consent granted';
      text.style.color = '#10b981';
    } else {
      text.textContent = '⚠️ No active data collection consent';
      text.style.color = '#ef4444';
    }
  }

  async refresh() {
    const data = await this.fetchAnalytics();
    if (!data) return;

    this.updateSummaryStats(data.summary);
    this.renderActivityTimeline(data.activity_timeline);
    this.renderAppUsage(data.app_usage);
    this.renderPeakHours(data.peak_hours);
    this.renderHeatmap(data.hourly_heatmap);
    this.renderSessionSummary(data.sessions, data.word_count);
  }

  updateSummaryStats(summary) {
    const fields = ['total_keystrokes', 'unique_apps', 'active_days', 'avg_keystrokes_per_day'];
    fields.forEach(f => {
      const el = document.getElementById(`stat-${f}`);
      if (el) el.textContent = summary[f]?.toLocaleString() ?? '—';
    });
  }

  renderActivityTimeline(data) {
    this.destroyChart('activity');
    const canvas = document.getElementById('keylog-activity-chart');
    if (!canvas || !data?.length) return;

    const granularity = document.getElementById('timeline-granularity')?.value || 'daily';
    let labels, values;

    if (granularity === 'daily' || !data[0]?.hour) {
      labels = data.map(d => d.date);
      values = data.map(d => d.count);
    } else {
      labels = data.map(d => `${d.date} ${String(d.hour).padStart(2, '0')}:00`);
      values = data.map(d => d.count);
    }

    this.charts.activity = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: 'Keystrokes',
          data: values,
          backgroundColor: 'rgba(59, 130, 246, 0.6)',
          borderColor: '#3b82f6',
          borderWidth: 1,
          borderRadius: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: '#9ca3af', maxTicksLimit: 15 }, grid: { color: 'rgba(75,85,99,0.3)' } },
          y: { ticks: { color: '#9ca3af' }, grid: { color: 'rgba(75,85,99,0.3)' }, beginAtZero: true }
        }
      }
    });
  }

  renderAppUsage(data) {
    this.destroyChart('appUsage');
    const canvas = document.getElementById('keylog-app-usage-chart');
    if (!canvas || !data?.length) return;

    const top10 = data.slice(0, 10);
    const colors = ['#3b82f6','#8b5cf6','#ec4899','#f59e0b','#10b981','#06b6d4','#f97316','#84cc16','#e11d48','#6366f1'];

    this.charts.appUsage = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: top10.map(d => d.app_package?.split('.').pop() || d.app_package),
        datasets: [{
          data: top10.map(d => d.keystroke_count),
          backgroundColor: colors.slice(0, top10.length),
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'right', labels: { color: '#e5e7eb', padding: 12, font: { size: 11 } } }
        }
      }
    });
  }

  renderPeakHours(data) {
    this.destroyChart('peakHours');
    const canvas = document.getElementById('keylog-peak-hours-chart');
    if (!canvas || !data?.length) return;

    this.charts.peakHours = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map(d => `${String(d.hour).padStart(2, '0')}:00`),
        datasets: [{
          label: 'Keystrokes',
          data: data.map(d => d.count),
          backgroundColor: 'rgba(139, 92, 246, 0.6)',
          borderColor: '#8b5cf6',
          borderWidth: 1,
          borderRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: '#9ca3af' }, grid: { color: 'rgba(75,85,99,0.3)' }, beginAtZero: true },
          y: { ticks: { color: '#9ca3af' }, grid: { display: false } }
        }
      }
    });
  }

  renderHeatmap(data) {
    this.destroyChart('heatmap');
    const canvas = document.getElementById('keylog-heatmap-chart');
    if (!canvas || !data?.length) return;

    const datasets = data.map((dayData, dayIdx) => ({
      label: dayData.day,
      data: dayData.hours.map((val, hour) => ({ x: hour, y: dayIdx, v: val })),
      backgroundColor: dayData.hours.map(v => {
        const max = Math.max(...data.flatMap(d => d.hours), 1);
        const intensity = Math.min(v / max, 1);
        return `rgba(59, 130, 246, ${0.1 + intensity * 0.8})`;
      }),
      borderWidth: 1,
      borderColor: 'rgba(30,41,59,0.8)',
      borderRadius: 2
    }));

    // Flatten to bubble-like representation using a bar chart matrix
    const flatData = [];
    data.forEach((dayData, dayIdx) => {
      dayData.hours.forEach((val, hour) => {
        flatData.push({ x: hour, y: dayIdx, v: val });
      });
    });

    const maxVal = Math.max(...flatData.map(d => d.v), 1);

    this.charts.heatmap = new Chart(canvas, {
      type: 'bubble',
      data: {
        datasets: [{
          label: 'Activity',
          data: flatData.map(d => ({ x: d.x, y: d.y, r: Math.max(2, (d.v / maxVal) * 14) })),
          backgroundColor: flatData.map(d => {
            const intensity = d.v / maxVal;
            return `rgba(59, 130, 246, ${0.15 + intensity * 0.75})`;
          })
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: {
            min: -0.5, max: 23.5,
            ticks: { color: '#9ca3af', callback: v => `${String(v).padStart(2, '0')}:00`, stepSize: 3 },
            grid: { color: 'rgba(75,85,99,0.15)' }
          },
          y: {
            min: -0.5, max: 6.5,
            ticks: { color: '#9ca3af', callback: v => ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][v] || '' },
            grid: { color: 'rgba(75,85,99,0.15)' }
          }
        }
      }
    });
  }

  renderSessionSummary(sessions, wordCount) {
    const container = document.getElementById('session-summary');
    if (!container) return;

    container.innerHTML = `
      <div class="metric-item"><div class="metric-value"><span class="big-number">${sessions?.total_sessions ?? 0}</span></div><div class="metric-label">Total Sessions</div></div>
      <div class="metric-item"><div class="metric-value"><span class="big-number">${sessions?.avg_session_minutes ?? 0}</span></div><div class="metric-label">Avg Session (min)</div></div>
      <div class="metric-item"><div class="metric-value"><span class="big-number">${sessions?.longest_session_minutes ?? 0}</span></div><div class="metric-label">Longest Session (min)</div></div>
      <div class="metric-item"><div class="metric-value"><span class="big-number">${wordCount?.estimated_words?.toLocaleString() ?? 0}</span></div><div class="metric-label">Estimated Words</div></div>
      <div class="metric-item"><div class="metric-value"><span class="big-number">${wordCount?.total_characters?.toLocaleString() ?? 0}</span></div><div class="metric-label">Total Characters</div></div>
    `;
  }

  exportReport(format) {
    const url = `/api/devices/${this.deviceId}/keylog_analytics/export?export_format=${format}&${this.dateParams()}`;
    if (format === 'csv') {
      window.location.href = url;
    } else {
      window.open(url, '_blank');
    }
  }

  destroyChart(name) {
    if (this.charts[name]) {
      this.charts[name].destroy();
      delete this.charts[name];
    }
  }
}

// Make available globally for ActiveAdmin page
window.KeylogDashboard = KeylogDashboard;

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('analytics-device-select')) {
    window.keylogDashboard = new KeylogDashboard();
  }
});
