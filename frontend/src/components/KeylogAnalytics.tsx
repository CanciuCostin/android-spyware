import React, { useEffect, useState, useCallback, useRef } from 'react';
import Chart from 'react-apexcharts';
import type { ApexOptions } from 'apexcharts';
import { colorPalettes } from '../../utils/chartConfig';

interface AnalyticsSummary {
  total_keystrokes: number;
  unique_apps: number;
  active_days: number;
  avg_keystrokes_per_day: number;
  date_range: { start: string; end: string };
}

interface AppUsageItem {
  app_package: string;
  keystroke_count: number;
  percentage: number;
}

interface TimelineItem {
  date: string;
  hour?: number;
  count: number;
}

interface HeatmapDay {
  day: string;
  hours: number[];
}

interface PeakHour {
  hour: number;
  count: number;
}

interface SessionInfo {
  total_sessions: number;
  avg_session_minutes: number;
  longest_session_minutes: number;
}

interface WordCount {
  total_characters: number;
  estimated_words: number;
  text_events: number;
}

interface AnalyticsData {
  summary: AnalyticsSummary;
  app_usage: AppUsageItem[];
  activity_timeline: TimelineItem[];
  hourly_heatmap: HeatmapDay[];
  peak_hours: PeakHour[];
  sessions: SessionInfo;
  word_count: WordCount;
}

interface KeylogAnalyticsProps {
  deviceId: string;
  apiBasePath?: string;
}

export const KeylogAnalytics: React.FC<KeylogAnalyticsProps> = ({
  deviceId,
  apiBasePath = '/api',
}) => {
  const [analytics, setAnalytics] = useState<AnalyticsData | null>(null);
  const [consentStatus, setConsentStatus] = useState<string>('checking');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [days, setDays] = useState(30);
  const [appFilter, setAppFilter] = useState<string>('');

  const dateRange = useCallback(() => {
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - days);
    return { start: start.toISOString(), end: end.toISOString() };
  }, [days]);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { start, end } = dateRange();
      const resp = await fetch(
        `${apiBasePath}/devices/${deviceId}/keylog_analytics?start_date=${start}&end_date=${end}`
      );
      if (resp.status === 403) {
        setConsentStatus('denied');
        setError('Data collection consent not granted for this device.');
        return;
      }
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      setConsentStatus(data.consent_status || 'unknown');
      setAnalytics(data.analytics);
    } catch (e: any) {
      setError(e.message || 'Failed to load analytics');
    } finally {
      setLoading(false);
    }
  }, [deviceId, days, apiBasePath, dateRange]);

  useEffect(() => { fetchData(); }, [fetchData]);

  const handleExport = (format: string) => {
    const { start, end } = dateRange();
    const url = `${apiBasePath}/devices/${deviceId}/keylog_analytics/export?export_format=${format}&start_date=${start}&end_date=${end}`;
    if (format === 'csv') {
      window.location.href = url;
    } else {
      window.open(url, '_blank');
    }
  };

  const filteredAppUsage = analytics?.app_usage?.filter(a =>
    !appFilter || a.app_package.toLowerCase().includes(appFilter.toLowerCase())
  ) || [];

  // --- Chart configs ---
  const timelineOptions: ApexOptions = {
    chart: { type: 'bar', background: 'transparent', foreColor: '#e5e7eb', toolbar: { show: true } },
    theme: { mode: 'dark' },
    title: { text: 'Typing Activity Over Time', style: { fontSize: '16px', color: '#f9fafb' } },
    xaxis: { categories: analytics?.activity_timeline?.map(t => t.date) || [], labels: { style: { colors: '#9ca3af' } } },
    yaxis: { labels: { style: { colors: '#9ca3af' } } },
    colors: ['#3b82f6'],
    plotOptions: { bar: { borderRadius: 3 } },
    grid: { borderColor: 'rgba(75,85,99,0.3)' }
  };

  const appUsageOptions: ApexOptions = {
    chart: { type: 'donut', background: 'transparent', foreColor: '#e5e7eb' },
    theme: { mode: 'dark' },
    title: { text: 'App Usage Distribution', style: { fontSize: '16px', color: '#f9fafb' } },
    labels: filteredAppUsage.slice(0, 10).map(a => a.app_package?.split('.').pop() || a.app_package),
    colors: colorPalettes.primary,
    legend: { position: 'right', labels: { colors: '#e5e7eb' } },
    plotOptions: { pie: { donut: { labels: { show: true, total: { show: true, label: 'Total', color: '#e5e7eb' } } } } }
  };

  const heatmapSeries = analytics?.hourly_heatmap?.map(d => ({
    name: d.day,
    data: d.hours.map((v, h) => ({ x: `${String(h).padStart(2, '0')}:00`, y: v }))
  })) || [];

  const heatmapOptions: ApexOptions = {
    chart: { type: 'heatmap', background: 'transparent', foreColor: '#e5e7eb', toolbar: { show: true } },
    theme: { mode: 'dark' },
    title: { text: 'Activity Heatmap', style: { fontSize: '16px', color: '#f9fafb' } },
    dataLabels: { enabled: false },
    colors: ['#3b82f6'],
    grid: { borderColor: 'rgba(75,85,99,0.3)' }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500" />
        <span className="ml-3 text-gray-400">Loading analytics...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Consent Badge */}
      <div className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm ${
        consentStatus === 'granted' ? 'bg-green-900/30 border border-green-700 text-green-400'
        : consentStatus === 'denied' ? 'bg-red-900/30 border border-red-700 text-red-400'
        : 'bg-yellow-900/30 border border-yellow-700 text-yellow-400'
      }`}>
        <span>{consentStatus === 'granted' ? '🔒 ✅' : consentStatus === 'denied' ? '🔒 ❌' : '🔒 ⏳'}</span>
        <span>
          Consent: {consentStatus === 'granted' ? 'Data collection consent granted'
            : consentStatus === 'denied' ? 'No active consent — analytics unavailable'
            : 'Checking consent status...'}
        </span>
      </div>

      {error && (
        <div className="bg-red-900/30 border border-red-700 text-red-400 px-4 py-3 rounded-lg">{error}</div>
      )}

      {/* Controls */}
      <div className="flex flex-wrap items-center gap-4">
        {/* Date Range */}
        <div className="flex gap-2">
          {[7, 30, 90].map(d => (
            <button
              key={d}
              onClick={() => setDays(d)}
              className={`px-3 py-1.5 text-sm rounded transition ${
                days === d ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }`}
            >
              {d} Days
            </button>
          ))}
        </div>

        {/* App Filter */}
        <input
          type="text"
          placeholder="Filter apps..."
          value={appFilter}
          onChange={e => setAppFilter(e.target.value)}
          className="px-3 py-1.5 text-sm bg-gray-700 border border-gray-600 rounded text-gray-200 placeholder-gray-500 focus:outline-none focus:border-blue-500"
        />

        {/* Export */}
        <div className="flex gap-2 ml-auto">
          <button onClick={() => handleExport('csv')} className="px-3 py-1.5 text-sm bg-gray-700 hover:bg-gray-600 rounded text-gray-300 transition">
            📥 CSV
          </button>
          <button onClick={() => handleExport('json')} className="px-3 py-1.5 text-sm bg-gray-700 hover:bg-gray-600 rounded text-gray-300 transition">
            📥 JSON
          </button>
        </div>
      </div>

      {analytics && (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Total Keystrokes', value: analytics.summary.total_keystrokes.toLocaleString() },
              { label: 'Unique Apps', value: analytics.summary.unique_apps },
              { label: 'Active Days', value: analytics.summary.active_days },
              { label: 'Avg/Day', value: analytics.summary.avg_keystrokes_per_day },
            ].map(stat => (
              <div key={stat.label} className="bg-gray-800 rounded-lg p-4 shadow-lg">
                <div className="text-2xl font-bold text-white">{stat.value}</div>
                <div className="text-sm text-gray-400 mt-1">{stat.label}</div>
              </div>
            ))}
          </div>

          {/* Activity Timeline */}
          <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
            <Chart
              options={timelineOptions}
              series={[{ name: 'Keystrokes', data: analytics.activity_timeline?.map(t => t.count) || [] }]}
              type="bar"
              height={300}
            />
          </div>

          {/* App Usage + Peak Hours */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
              <Chart
                options={appUsageOptions}
                series={filteredAppUsage.slice(0, 10).map(a => a.keystroke_count)}
                type="donut"
                height={300}
              />
            </div>
            <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
              <Chart
                options={{
                  chart: { type: 'bar', background: 'transparent', foreColor: '#e5e7eb' },
                  theme: { mode: 'dark' },
                  title: { text: 'Peak Activity Hours', style: { fontSize: '16px', color: '#f9fafb' } },
                  xaxis: { categories: analytics.peak_hours?.map(p => `${String(p.hour).padStart(2, '0')}:00`) || [] },
                  colors: ['#8b5cf6'],
                  plotOptions: { bar: { horizontal: true, borderRadius: 4 } },
                  grid: { borderColor: 'rgba(75,85,99,0.3)' }
                }}
                series={[{ name: 'Keystrokes', data: analytics.peak_hours?.map(p => p.count) || [] }]}
                type="bar"
                height={300}
              />
            </div>
          </div>

          {/* Heatmap */}
          <div className="bg-gray-800 rounded-lg p-4 shadow-lg">
            <Chart
              options={heatmapOptions}
              series={heatmapSeries}
              type="heatmap"
              height={250}
            />
          </div>

          {/* Session & Word Count */}
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            {[
              { label: 'Sessions', value: analytics.sessions.total_sessions },
              { label: 'Avg Session (min)', value: analytics.sessions.avg_session_minutes },
              { label: 'Longest (min)', value: analytics.sessions.longest_session_minutes },
              { label: 'Est. Words', value: analytics.word_count.estimated_words.toLocaleString() },
              { label: 'Characters', value: analytics.word_count.total_characters.toLocaleString() },
            ].map(stat => (
              <div key={stat.label} className="bg-gray-800 rounded-lg p-4 shadow-lg text-center">
                <div className="text-xl font-bold text-white">{stat.value}</div>
                <div className="text-xs text-gray-400 mt-1">{stat.label}</div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
};

export default KeylogAnalytics;
