import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/global.css'
import App from './App.tsx'
import { reportWebVitals } from './utils/webVitals'

// Initialize web vitals tracking
reportWebVitals({
  enabled: true,
  debug: import.meta.env.DEV,
  onReport: (metric) => {
    // Send to analytics in production
    if (!import.meta.env.DEV) {
      // Example: sendToAnalytics(metric);
      console.log('Web Vital:', metric);
    }
  },
});

// Enable axe-core in development
if (import.meta.env.DEV) {
  import('@axe-core/react').then(async (axe) => {
    const React = await import('react');
    const ReactDOM = await import('react-dom');
    axe.default(React, ReactDOM, 1000);
  }).catch(() => {
    // Axe-core not available, ignore
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
