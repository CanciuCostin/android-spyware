/**
 * Notification Manager - Toast notification system for EagleSpy V5
 *
 * Provides a global API for showing toast notifications with
 * auto-dismiss, stacking, and type-based styling.
 *
 * @module notification_manager
 */

/**
 * @typedef {'success'|'error'|'warning'|'info'} ToastType
 */

/**
 * @typedef {Object} ToastOptions
 * @property {string} message - Notification message
 * @property {ToastType} [type='info'] - Toast type
 * @property {number} [duration=5000] - Auto-dismiss delay in ms (0 = sticky)
 */

/** @type {HTMLElement|null} */
let container = null;

const ICONS = Object.freeze({
  success: '✅',
  error: '❌',
  warning: '⚠️',
  info: 'ℹ️'
});

/**
 * Ensure the toast container exists in the DOM.
 * @returns {HTMLElement}
 */
const ensureContainer = () => {
  if (container && document.body.contains(container)) return container;

  container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'toast-container';
    document.body.appendChild(container);
  }
  return container;
};

/**
 * Remove a toast element with exit animation.
 * @param {HTMLElement} toast
 */
const removeToast = (toast) => {
  toast.classList.add('toast-exit');
  setTimeout(() => toast.remove(), 200);
};

/**
 * Show a toast notification.
 * @param {string} message
 * @param {ToastType} [type='info']
 * @param {number} [duration=5000]
 * @returns {HTMLElement} The toast element
 */
export const showToast = (message, type = 'info', duration = 5000) => {
  const parent = ensureContainer();
  const icon = ICONS[type] || ICONS.info;

  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;

  const iconSpan = document.createElement('span');
  iconSpan.className = 'toast-icon';
  iconSpan.textContent = icon;

  const contentDiv = document.createElement('div');
  contentDiv.className = 'toast-content';
  const msgDiv = document.createElement('div');
  msgDiv.className = 'toast-message';
  msgDiv.textContent = message;
  contentDiv.appendChild(msgDiv);

  const closeBtn = document.createElement('button');
  closeBtn.className = 'toast-close';
  closeBtn.setAttribute('aria-label', 'Close');
  closeBtn.textContent = '✕';

  toast.appendChild(iconSpan);
  toast.appendChild(contentDiv);
  toast.appendChild(closeBtn);

  if (duration > 0) {
    const progressDiv = document.createElement('div');
    progressDiv.className = 'toast-progress';
    toast.appendChild(progressDiv);
  }

  closeBtn.addEventListener('click', () => removeToast(toast));

  parent.appendChild(toast);

  if (duration > 0) {
    setTimeout(() => removeToast(toast), duration);
  }

  return toast;
};

/**
 * Convenience methods for each toast type.
 * @param {string} message
 * @param {number} [duration=5000]
 * @returns {HTMLElement}
 */
export const success = (message, duration) => showToast(message, 'success', duration);
export const error = (message, duration) => showToast(message, 'error', duration);
export const warning = (message, duration) => showToast(message, 'warning', duration);
export const info = (message, duration) => showToast(message, 'info', duration);

/**
 * Clear all visible toasts.
 */
export const clearAll = () => {
  const parent = ensureContainer();
  while (parent.firstChild) {
    parent.removeChild(parent.firstChild);
  }
};

export default { showToast, success, error, warning, info, clearAll };
