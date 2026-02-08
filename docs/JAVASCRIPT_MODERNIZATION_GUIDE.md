# JavaScript Modernization Guide – EagleSpy V5

## Overview

This document describes the ES6+ modernization applied to the EagleSpy V5 JavaScript codebase, covering module architecture, code-splitting strategy, and JSDoc type annotations.

---

## 1. Module Architecture

All new shared logic lives under `app/javascript/modules/`:

| Module | Purpose |
|---|---|
| `websocket_manager.js` | ActionCable wrapper with subscription management, message queuing, and auto-reconnect awareness |
| `api_client.js` | Fetch API wrapper with automatic CSRF token injection, JSON handling, and file-upload progress |
| `notification_manager.js` | Toast notification system (`success`, `error`, `warning`, `info`) with auto-dismiss |
| `theme_manager.js` | Dark/light theme toggle persisted in `localStorage`, with system-preference detection |
| `chart_manager.js` | Lazy-loaded Chart.js wrapper that manages chart lifecycle, updates, and PNG/PDF export |

### Importing a module

```js
// Named imports (tree-shakeable)
import { get, post } from '../modules/api_client';
import { showToast } from '../modules/notification_manager';

// Default import (full namespace)
import apiClient from '../modules/api_client';
```

---

## 2. ES6+ Conventions

The following conventions are applied across all modernized files:

| Before | After |
|---|---|
| `var` | `const` / `let` |
| `function(){}` | Arrow functions `() => {}` |
| String concatenation | Template literals `` `${var}` `` |
| Callbacks / `.then()` | `async` / `await` |
| `require()` | ES6 `import` / `export` |
| `obj.prop = obj.prop` | Destructuring `const { prop } = obj` |

### Example: API call (before)

```js
var response = $.ajax({ url: '/devices', method: 'GET' });
response.done(function(data) {
  console.log('Got ' + data.length + ' devices');
});
```

### Example: API call (after)

```js
import { get } from '../modules/api_client';

const { data } = await get('/devices');
console.log(`Got ${data.length} devices`);
```

---

## 3. Code Splitting

Webpack is configured in `config/webpack/environment.js` for automatic code splitting:

### Chunk strategy

| Chunk | Contents | Loading |
|---|---|---|
| `vendor` | All `node_modules` (jQuery, Bootstrap, Rails UJS, etc.) | Eager – loaded on every page |
| `chartjs` | `chart.js` + `chartjs-adapter-date-fns` | Lazy – loaded only on pages with `[data-controller="charts"]` |
| `xterm` | Xterm.js terminal emulator | Lazy – loaded only when `#terminal-container` exists |
| `export-utils` | `html2canvas` + `jspdf` | Lazy – loaded on first chart export |

### Dynamic imports

Heavy modules are loaded with Webpack dynamic `import()`:

```js
// In application.js
if (document.querySelector('[data-controller="charts"]')) {
  const { default: chartManager } = await import(
    /* webpackChunkName: "charts" */ '../modules/chart_manager'
  );
}
```

Inside `chart_manager.js`, Chart.js itself is also lazy-loaded:

```js
const loadChartJS = async () => {
  const { default: Chart } = await import(
    /* webpackChunkName: "chartjs" */ 'chart.js/auto'
  );
  // ...
};
```

---

## 4. Entry Points

### `app/javascript/packs/application.js` (main)

Eagerly imports only:
- `@rails/ujs`
- `@rails/activestorage`
- `@rails/actioncable`
- `turbolinks`
- Stylesheets
- ActionCable channels

Everything else is lazy-loaded based on DOM presence.

### Other packs

| Pack | Purpose |
|---|---|
| `dashboard.js` | Stimulus application bootstrap |
| `smartphones.js` | Phone list modal (modernised to `const`/`let` + arrow functions) |
| `charts.js` | Original chart pack (still functional, new code uses `chart_manager` module) |
| `modern_dashboard.js` | Theme toggle, toasts, modals, responsive sidebar |
| `webrtc_client.js` | WebRTC peer connection and signaling |
| `chunked_uploader.js` | Chunked file uploads with progress |
| `instructions.js` | jQuery slider plugin (legacy, unchanged) |

---

## 5. JSDoc Type Annotations

All new modules include JSDoc type annotations for editor IntelliSense support without requiring TypeScript compilation.

### Key annotated types

#### `api_client.js`

```js
/**
 * @typedef {Object} ApiResponse
 * @property {boolean} ok
 * @property {number} status
 * @property {*} data
 * @property {Object} headers
 */
```

#### `websocket_manager.js`

```js
/**
 * @typedef {Object} SubscriptionCallbacks
 * @property {function(): void} [connected]
 * @property {function(): void} [disconnected]
 * @property {function(Object): void} [received]
 */
```

#### `chart_manager.js`

```js
/**
 * @typedef {Object} ChartConfig
 * @property {string} type
 * @property {string[]} labels
 * @property {ChartDataset[]} datasets
 * @property {Object} [options]
 */
```

---

## 6. Migration Tips

### Using the new API client instead of jQuery AJAX

```js
// Before
$.ajax({
  url: '/devices/' + id + '/commands',
  method: 'POST',
  data: JSON.stringify({ command: 'screenshot' }),
  contentType: 'application/json',
  headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
});

// After
import { post } from '../modules/api_client';
await post(`/devices/${id}/commands`, { command: 'screenshot' });
```

### Using the notification manager

```js
import { success, error } from '../modules/notification_manager';

try {
  await post('/devices/1/commands', { command: 'screenshot' });
  success('Screenshot command sent');
} catch (err) {
  error(err.message);
}
```

### Using the WebSocket manager

```js
import { subscribe, send } from '../modules/websocket_manager';

const sub = subscribe('SignalingChannel', { device_id: 42 }, {
  received: (msg) => console.log('Got:', msg)
});

send('SignalingChannel', { type: 'ping' }, { device_id: 42 });
```

---

## 7. File Structure

```
app/javascript/
├── channels/
│   ├── consumer.js          # ActionCable consumer (unchanged)
│   └── index.js             # Channel autoloader (unchanged)
├── controllers/
│   └── dashboard_controller.js  # Stimulus controller (unchanged)
├── modules/                  # ← NEW shared ES6 modules
│   ├── api_client.js
│   ├── chart_manager.js
│   ├── notification_manager.js
│   ├── theme_manager.js
│   └── websocket_manager.js
├── packs/
│   ├── application.js        # Main entry (modernised)
│   ├── charts.js             # Chart pack (unchanged)
│   ├── chunked_uploader.js   # Upload pack (unchanged)
│   ├── dashboard.js          # Stimulus bootstrap (unchanged)
│   ├── instructions.js       # jQuery slider (legacy)
│   ├── modern_dashboard.js   # Dashboard UI (unchanged)
│   ├── smartphones.js        # Phone list (modernised)
│   └── webrtc_client.js      # WebRTC client (unchanged)
└── stylesheets/
    └── application.*
```
