/**
 * Theme Manager - Dark/light theme toggle for EagleSpy V5
 *
 * Persists user preference in localStorage and applies theme
 * classes to the document body. Supports programmatic switching
 * and system preference detection.
 *
 * @module theme_manager
 */

/**
 * @typedef {'dark'|'light'} Theme
 */

const STORAGE_KEY = 'eagle-theme';

/** @type {Set<function(Theme): void>} */
const listeners = new Set();

/**
 * Get the currently active theme.
 * @returns {Theme}
 */
export const current = () => localStorage.getItem(STORAGE_KEY) || 'dark';

/**
 * Detect the OS-level color scheme preference.
 * @returns {Theme}
 */
export const systemPreference = () => {
  if (window.matchMedia?.('(prefers-color-scheme: light)').matches) {
    return 'light';
  }
  return 'dark';
};

/**
 * Apply a theme to the document.
 * @param {Theme} theme
 */
export const setTheme = (theme) => {
  document.body.classList.add('theme-transitioning');

  document.body.classList.remove('light-mode', 'dark-mode');
  document.body.classList.add(`${theme}-mode`);
  document.body.setAttribute('data-theme', theme);

  // Update toggle buttons if present
  document.querySelector('.theme-toggle .toggle-option.active')?.classList.remove('active');
  document.querySelector(`.theme-toggle .toggle-option[data-theme="${theme}"]`)?.classList.add('active');

  localStorage.setItem(STORAGE_KEY, theme);

  setTimeout(() => {
    document.body.classList.remove('theme-transitioning');
  }, 50);

  listeners.forEach((fn) => fn(theme));
};

/**
 * Toggle between dark and light themes.
 * @returns {Theme} The newly active theme
 */
export const toggle = () => {
  const next = current() === 'dark' ? 'light' : 'dark';
  setTheme(next);
  return next;
};

/**
 * Register a callback that fires whenever the theme changes.
 * @param {function(Theme): void} fn
 * @returns {function(): void} Unsubscribe function
 */
export const onChange = (fn) => {
  listeners.add(fn);
  return () => listeners.delete(fn);
};

/**
 * Initialize theme from stored preference (call once on page load).
 */
export const init = () => {
  const saved = localStorage.getItem(STORAGE_KEY);
  setTheme(saved || systemPreference());
};

export default { current, systemPreference, setTheme, toggle, onChange, init };
