/**
 * Preference Manager - Loads, saves, and applies user preferences.
 * Syncs with server via /api/preferences endpoints.
 *
 * @module preference_manager
 */

const API_URL = '/api/preferences';
const STORAGE_KEY = 'eagle-preferences';
const SYNC_DEBOUNCE_MS = 1000;

let preferences = {};
let syncTimer = null;
let initialized = false;

/**
 * Get CSRF token from meta tag.
 * @returns {string}
 */
function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : '';
}

/**
 * Load preferences from server, falling back to localStorage.
 * @returns {Promise<Object>}
 */
export async function load() {
  try {
    const response = await fetch(API_URL, {
      headers: { 'Accept': 'application/json' }
    });

    if (response.ok) {
      const data = await response.json();
      preferences = data.preferences || {};
      localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences));
      return preferences;
    }
  } catch (e) {
    console.warn('[PreferenceManager] Server fetch failed, using local cache', e);
  }

  // Fallback to localStorage
  try {
    const cached = localStorage.getItem(STORAGE_KEY);
    if (cached) {
      preferences = JSON.parse(cached);
    }
  } catch (e) {
    console.warn('[PreferenceManager] localStorage parse failed', e);
    preferences = {};
  }

  return preferences;
}

/**
 * Save preferences to server.
 * @param {Object} newPrefs - Preferences to merge/save
 * @returns {Promise<Object>}
 */
export async function save(newPrefs) {
  Object.assign(preferences, newPrefs);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences));

  // Debounced server sync
  if (syncTimer) clearTimeout(syncTimer);
  syncTimer = setTimeout(() => syncToServer(newPrefs), SYNC_DEBOUNCE_MS);

  return preferences;
}

/**
 * Get a preference value by dot-notation key.
 * @param {string} keyPath - e.g. 'theme.mode' or 'dashboard.layout'
 * @param {*} defaultValue - Fallback if key not found
 * @returns {*}
 */
export function get(keyPath, defaultValue) {
  const keys = keyPath.split('.');
  let current = preferences;

  for (const key of keys) {
    if (current == null || typeof current !== 'object') return defaultValue;
    current = current[key];
  }

  return current !== undefined ? current : defaultValue;
}

/**
 * Set a preference value by dot-notation key and sync.
 * @param {string} keyPath
 * @param {*} value
 */
export function set(keyPath, value) {
  const keys = keyPath.split('.');
  let current = preferences;

  for (let i = 0; i < keys.length - 1; i++) {
    if (!current[keys[i]] || typeof current[keys[i]] !== 'object') {
      current[keys[i]] = {};
    }
    current = current[keys[i]];
  }

  current[keys[keys.length - 1]] = value;
  save(preferences);
}

/**
 * Reset preferences to server defaults.
 * @returns {Promise<Object>}
 */
export async function reset() {
  try {
    const response = await fetch(API_URL, {
      method: 'DELETE',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken()
      }
    });

    if (response.ok) {
      const data = await response.json();
      preferences = data.preferences || {};
      localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences));
      applyAll();
      return preferences;
    }
  } catch (e) {
    console.error('[PreferenceManager] Reset failed', e);
  }

  return preferences;
}

/**
 * Apply all preferences to the page.
 */
export function applyAll() {
  applyTheme();
  applyDashboard();
  applyData();
}

/**
 * Apply theme preferences.
 */
function applyTheme() {
  const mode = get('theme.mode', 'dark');
  const fontSize = get('theme.font_size', 'medium');
  const accent = get('theme.accent_color', '#00d4ff');
  const compact = get('theme.compact_mode', false);

  document.body.classList.remove('light-mode', 'dark-mode');
  document.body.classList.add(`${mode}-mode`);
  document.body.setAttribute('data-theme', mode);
  document.body.setAttribute('data-font-size', fontSize);
  document.documentElement.style.setProperty('--accent-color', accent);

  if (compact) {
    document.body.classList.add('compact-mode');
  } else {
    document.body.classList.remove('compact-mode');
  }
}

/**
 * Apply dashboard layout preferences.
 */
function applyDashboard() {
  const layout = get('dashboard.layout', 'grid');
  const container = document.querySelector('.device-cards, .index_as_table');
  if (container) {
    container.setAttribute('data-layout', layout);
  }

  const refreshInterval = get('dashboard.refresh_interval', 30);
  const autoRefresh = get('dashboard.auto_refresh', true);
  if (autoRefresh && window.chartManager) {
    window.chartManager.setRefreshInterval(refreshInterval * 1000);
  }
}

/**
 * Apply data display preferences.
 */
function applyData() {
  const fontSize = get('theme.font_size', 'medium');
  const sizes = { small: '12px', medium: '14px', large: '16px' };
  document.documentElement.style.setProperty('--base-font-size', sizes[fontSize] || '14px');
}

/**
 * Sync preferences to server.
 * @param {Object} prefs
 */
async function syncToServer(prefs) {
  try {
    await fetch(API_URL, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken()
      },
      body: JSON.stringify({ preferences: prefs })
    });
  } catch (e) {
    console.warn('[PreferenceManager] Server sync failed', e);
  }
}

/**
 * Initialize preference manager on page load.
 */
export async function init() {
  if (initialized) return preferences;
  initialized = true;

  await load();
  applyAll();

  return preferences;
}

export default { init, load, save, get, set, reset, applyAll };
