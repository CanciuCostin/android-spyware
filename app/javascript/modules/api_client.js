/**
 * API Client - Fetch API wrapper with CSRF and auth for EagleSpy V5
 *
 * Provides a consistent interface for making authenticated HTTP requests
 * to Rails API endpoints with automatic CSRF token handling.
 *
 * @module api_client
 */

/**
 * @typedef {Object} ApiResponse
 * @property {boolean} ok - Whether the request was successful
 * @property {number} status - HTTP status code
 * @property {*} data - Parsed response body
 * @property {Object} headers - Response headers
 */

/**
 * @typedef {Object} RequestOptions
 * @property {Object} [headers] - Additional headers
 * @property {Object|string} [body] - Request body
 * @property {Object} [params] - Query parameters
 * @property {AbortSignal} [signal] - AbortController signal
 */

/**
 * Get the CSRF token from the Rails meta tag.
 * @returns {string}
 */
const getCsrfToken = () => {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : '';
};

/**
 * Build a query string from a params object.
 * @param {Object} params
 * @returns {string}
 */
const buildQuery = (params = {}) => {
  const entries = Object.entries(params).filter(([, v]) => v != null);
  if (entries.length === 0) return '';
  return `?${new URLSearchParams(entries).toString()}`;
};

/**
 * Default headers for all requests.
 * @returns {Object}
 */
const defaultHeaders = () => ({
  'Accept': 'application/json',
  'X-Requested-With': 'XMLHttpRequest',
  'X-CSRF-Token': getCsrfToken()
});

/**
 * Execute an HTTP request and return a normalized response.
 * @param {string} method - HTTP method
 * @param {string} url - Request URL
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
const request = async (method, url, options = {}) => {
  const { headers = {}, body, params, signal } = options;
  const fullUrl = `${url}${buildQuery(params)}`;

  const fetchOptions = {
    method,
    headers: { ...defaultHeaders(), ...headers },
    credentials: 'same-origin',
    signal
  };

  if (body != null) {
    if (body instanceof FormData) {
      fetchOptions.body = body;
      // Let browser set Content-Type with boundary for FormData
      delete fetchOptions.headers['Content-Type'];
    } else {
      fetchOptions.headers['Content-Type'] = 'application/json';
      fetchOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
    }
  }

  const response = await fetch(fullUrl, fetchOptions);
  let data = null;

  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    data = await response.json();
  } else {
    data = await response.text();
  }

  if (!response.ok) {
    const error = new Error(data?.error || data?.message || `HTTP ${response.status}`);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return { ok: true, status: response.status, data, headers: response.headers };
};

/**
 * GET request.
 * @param {string} url
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
export const get = (url, options = {}) => request('GET', url, options);

/**
 * POST request.
 * @param {string} url
 * @param {Object|FormData} [body]
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
export const post = (url, body, options = {}) => request('POST', url, { ...options, body });

/**
 * PATCH request.
 * @param {string} url
 * @param {Object} [body]
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
export const patch = (url, body, options = {}) => request('PATCH', url, { ...options, body });

/**
 * PUT request.
 * @param {string} url
 * @param {Object} [body]
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
export const put = (url, body, options = {}) => request('PUT', url, { ...options, body });

/**
 * DELETE request.
 * @param {string} url
 * @param {RequestOptions} [options={}]
 * @returns {Promise<ApiResponse>}
 */
export const destroy = (url, options = {}) => request('DELETE', url, options);

/**
 * Upload a file with progress tracking (uses XMLHttpRequest for progress events).
 * @param {string} url
 * @param {FormData} formData
 * @param {function(number): void} [onProgress]
 * @returns {Promise<ApiResponse>}
 */
export const upload = (url, formData, onProgress) => {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', url, true);
    xhr.setRequestHeader('X-CSRF-Token', getCsrfToken());
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');

    if (onProgress) {
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          onProgress(Math.round((e.loaded / e.total) * 100));
        }
      });
    }

    xhr.onload = () => {
      let data;
      try {
        data = JSON.parse(xhr.responseText);
      } catch {
        data = xhr.responseText;
      }

      if (xhr.status >= 200 && xhr.status < 300) {
        resolve({ ok: true, status: xhr.status, data, headers: {} });
      } else {
        const error = new Error(data?.error || `HTTP ${xhr.status}`);
        error.status = xhr.status;
        error.data = data;
        reject(error);
      }
    };

    xhr.onerror = () => reject(new Error('Network error'));
    xhr.send(formData);
  });
};

export default { get, post, patch, put, destroy, upload };
