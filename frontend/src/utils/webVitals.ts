import { onCLS, onFID, onFCP, onLCP, onTTFB, type Metric } from 'web-vitals';

interface WebVitalsConfig {
  enabled?: boolean;
  onReport?: (metric: Metric) => void;
  debug?: boolean;
}

export function reportWebVitals(config: WebVitalsConfig = {}) {
  const { enabled = true, onReport, debug = false } = config;

  if (!enabled) return;

  const handleMetric = (metric: Metric) => {
    if (debug) {
      console.log('[Web Vitals]', metric);
    }

    if (onReport) {
      onReport(metric);
    }

    // You can also send to analytics service
    // Example: sendToAnalytics(metric);
  };

  onCLS(handleMetric);
  onFID(handleMetric);
  onFCP(handleMetric);
  onLCP(handleMetric);
  onTTFB(handleMetric);
}

// Helper to format metrics for display
export function formatMetric(metric: Metric): string {
  const value = Math.round(metric.value);
  const unit = metric.name === 'CLS' ? '' : 'ms';
  return `${metric.name}: ${value}${unit}`;
}

// Thresholds for Core Web Vitals
export const VITALS_THRESHOLDS = {
  LCP: { good: 2500, needsImprovement: 4000 },
  FID: { good: 100, needsImprovement: 300 },
  CLS: { good: 0.1, needsImprovement: 0.25 },
  FCP: { good: 1800, needsImprovement: 3000 },
  TTFB: { good: 800, needsImprovement: 1800 },
};

export function getRating(metric: Metric): 'good' | 'needs-improvement' | 'poor' {
  const thresholds = VITALS_THRESHOLDS[metric.name as keyof typeof VITALS_THRESHOLDS];
  if (!thresholds) return 'good';

  if (metric.value <= thresholds.good) return 'good';
  if (metric.value <= thresholds.needsImprovement) return 'needs-improvement';
  return 'poor';
}
