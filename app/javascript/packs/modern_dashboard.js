/**
 * EagleSpy V5 — Cyber Command Center
 * Dashboard JavaScript Engine
 *
 * Self-contained vanilla JS module for the ActiveAdmin dashboard.
 * Features: particle background, command palette, counter animations,
 * theme system, toast notifications, keyboard shortcuts, card effects,
 * responsive sidebar, Leaflet map integration, scan-line overlay.
 */

class CyberDashboard {
  constructor() {
    this._animFrameId = null;
    this._particles = [];
    this._resizeHandler = null;
    this._keydownHandler = null;
    this.init();
  }

  /** @private Bootstrap every subsystem. */
  init() {
    this.cleanup();
    this.initParticles();
    this.initCommandPalette();
    this.initCounterAnimations();
    this.initThemeSystem();
    this.initToastSystem();
    this.initKeyboardShortcuts();
    this.initCardEffects();
    this.initResponsiveMenu();
    this.initMapIntegration();
    this.initScanLineEffect();
  }

  /** @private Tear down previous instance listeners to avoid duplicates. */
  cleanup() {
    if (this._animFrameId) cancelAnimationFrame(this._animFrameId);
    if (this._resizeHandler) window.removeEventListener('resize', this._resizeHandler);
    if (this._keydownHandler) document.removeEventListener('keydown', this._keydownHandler);
    document.querySelector('.cyber-scan-line')?.remove();
    document.getElementById('cyber-command-palette')?.remove();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Particle Background
  // ═══════════════════════════════════════════════════════════════════

  /** @private Canvas-based floating particles with connecting lines. */
  initParticles() {
    const canvas = document.getElementById('particle-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    const resize = () => {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
    };
    resize();
    this._resizeHandler = resize;
    window.addEventListener('resize', this._resizeHandler);

    const count = window.innerWidth < 768 ? 20 : 50;
    this._particles = Array.from({ length: count }, () => ({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: 1 + Math.random() * 2,
      dx: (Math.random() - 0.5) * 0.5,
      dy: (Math.random() - 0.5) * 0.5,
      color: Math.random() > 0.5
        ? 'rgba(0,240,255,0.15)'
        : 'rgba(180,0,255,0.1)'
    }));

    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const pts = this._particles;

      for (let i = 0; i < pts.length; i++) {
        const p = pts[i];
        p.x += p.dx;
        p.y += p.dy;
        if (p.x < 0 || p.x > canvas.width) p.dx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.dy *= -1;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.fill();

        for (let j = i + 1; j < pts.length; j++) {
          const q = pts[j];
          const dist = Math.hypot(p.x - q.x, p.y - q.y);
          if (dist < 120) {
            ctx.beginPath();
            ctx.moveTo(p.x, p.y);
            ctx.lineTo(q.x, q.y);
            ctx.strokeStyle = `rgba(0,240,255,${0.08 * (1 - dist / 120)})`;
            ctx.stroke();
          }
        }
      }
      this._animFrameId = requestAnimationFrame(draw);
    };
    draw();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Command Palette  (Ctrl+K)
  // ═══════════════════════════════════════════════════════════════════

  /** @private Build the command palette overlay and populate commands. */
  initCommandPalette() {
    this._paletteOpen = false;
    this._paletteIndex = 0;

    /** @type {Array<{name:string, icon:string, action:string|Function, category:string}>} */
    this._commands = [
      // Surveillance
      { name: 'Live Camera – Front',   icon: '📸', action: '/admin/devices?scope=camera_front',    category: 'Surveillance' },
      { name: 'Live Camera – Back',    icon: '📷', action: '/admin/devices?scope=camera_back',     category: 'Surveillance' },
      { name: 'Take Photo',            icon: '🖼️', action: '/admin/commands/take_photo',           category: 'Surveillance' },
      { name: 'Live Microphone',       icon: '🎙️', action: '/admin/commands/live_mic',             category: 'Surveillance' },
      { name: 'Record Audio',          icon: '🔴', action: '/admin/commands/record_audio',         category: 'Surveillance' },
      { name: 'Live Screen',           icon: '🖥️', action: '/admin/commands/live_screen',          category: 'Surveillance' },
      { name: 'Screenshot',            icon: '📐', action: '/admin/commands/screenshot',           category: 'Surveillance' },
      // Data
      { name: 'SMS Messages',          icon: '💬', action: '/admin/sms_messages',                  category: 'Data' },
      { name: 'Call Logs',             icon: '📞', action: '/admin/call_logs',                     category: 'Data' },
      { name: 'Contacts',              icon: '👤', action: '/admin/contacts',                      category: 'Data' },
      { name: 'Keylogger',             icon: '⌨️', action: '/admin/keylogger_logs',                category: 'Data' },
      { name: 'Clipboard',             icon: '📋', action: '/admin/clipboard_logs',                category: 'Data' },
      { name: 'Notifications',         icon: '🔔', action: '/admin/notification_logs',             category: 'Data' },
      { name: 'Installed Apps',        icon: '📦', action: '/admin/installed_apps',                category: 'Data' },
      { name: 'Browser History',       icon: '🌐', action: '/admin/browser_history',               category: 'Data' },
      { name: 'WiFi Networks',         icon: '📶', action: '/admin/wifi_logs',                     category: 'Data' },
      // Control
      { name: 'Shell Command',         icon: '🐚', action: '/admin/commands/shell',                category: 'Control' },
      { name: 'File Manager',          icon: '📂', action: '/admin/file_manager',                  category: 'Control' },
      { name: 'Send SMS',              icon: '✉️', action: '/admin/commands/send_sms',             category: 'Control' },
      { name: 'Show Toast on Device',  icon: '💡', action: '/admin/commands/show_toast',           category: 'Control' },
      { name: 'Vibrate Device',        icon: '📳', action: '/admin/commands/vibrate',              category: 'Control' },
      { name: 'Lock Device',           icon: '🔒', action: '/admin/commands/lock',                 category: 'Control' },
      { name: 'Wipe Device',           icon: '🗑️', action: '/admin/commands/wipe',                 category: 'Control' },
      // AI
      { name: 'AI Analysis',           icon: '🤖', action: '/admin/ai_analysis',                   category: 'AI' },
      { name: 'AI Chat',               icon: '💬', action: '/admin/ai_chat',                       category: 'AI' },
      { name: 'Generate Report',       icon: '📊', action: '/admin/reports/new',                   category: 'AI' },
      // Navigation
      { name: 'Dashboard',             icon: '🏠', action: '/admin/dashboard',                     category: 'Navigation' },
      { name: 'Devices',               icon: '📱', action: '/admin/devices',                       category: 'Navigation' },
      { name: 'Locations',             icon: '📍', action: '/admin/locations',                     category: 'Navigation' },
      { name: 'Settings',              icon: '⚙️', action: '/admin/settings',                     category: 'Navigation' },
    ];

    // Build DOM
    const overlay = document.createElement('div');
    overlay.id = 'cyber-command-palette';
    overlay.style.cssText = 'display:none;position:fixed;inset:0;z-index:99999;' +
      'background:rgba(0,0,0,0.7);backdrop-filter:blur(4px);' +
      'justify-content:center;align-items:flex-start;padding-top:18vh;';
    overlay.innerHTML = `
      <div style="width:520px;max-width:92vw;background:#0d1117;border:1px solid rgba(0,240,255,0.25);
        border-radius:12px;box-shadow:0 8px 40px rgba(0,0,0,0.6);overflow:hidden;">
        <input id="cp-search" type="text" autocomplete="off"
          placeholder="Type a command… (Ctrl+K)"
          style="width:100%;padding:14px 18px;background:transparent;border:none;
            border-bottom:1px solid rgba(0,240,255,0.15);color:#e6edf3;font-size:15px;
            outline:none;font-family:inherit;" />
        <div id="cp-results" style="max-height:340px;overflow-y:auto;padding:6px 0;"></div>
      </div>`;
    document.body.appendChild(overlay);

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) this.closePalette();
    });
  }

  /** @param {string} query */
  _filterCommands(query) {
    if (!query) return this._commands;
    const q = query.toLowerCase();
    return this._commands.filter(c =>
      c.name.toLowerCase().includes(q) || c.category.toLowerCase().includes(q)
    );
  }

  /** @private Render filtered results in the palette list. */
  _renderPaletteResults(filtered) {
    const list = document.getElementById('cp-results');
    if (!list) return;
    if (!filtered.length) {
      list.innerHTML = '<div style="padding:18px;color:#8b949e;text-align:center;">No commands found</div>';
      return;
    }
    this._paletteIndex = Math.min(this._paletteIndex, filtered.length - 1);
    list.innerHTML = filtered.map((cmd, i) => {
      const active = i === this._paletteIndex
        ? 'background:rgba(0,240,255,0.1);' : '';
      return `<div class="cp-item" data-idx="${i}" style="${active}display:flex;align-items:center;
        gap:10px;padding:9px 18px;cursor:pointer;color:#c9d1d9;font-size:14px;
        transition:background .1s;">
        <span style="font-size:18px;">${cmd.icon}</span>
        <span style="flex:1;">${cmd.name}</span>
        <span style="font-size:11px;color:#8b949e;">${cmd.category}</span>
      </div>`;
    }).join('');

    list.querySelectorAll('.cp-item').forEach(el => {
      el.addEventListener('click', () => {
        this._executeCommand(filtered[parseInt(el.dataset.idx, 10)]);
      });
    });
  }

  /** @param {{action:string|Function}} cmd */
  _executeCommand(cmd) {
    this.closePalette();
    if (typeof cmd.action === 'function') { cmd.action(); return; }
    window.location.href = cmd.action;
  }

  openPalette() {
    const overlay = document.getElementById('cyber-command-palette');
    if (!overlay) return;
    overlay.style.display = 'flex';
    this._paletteOpen = true;
    this._paletteIndex = 0;
    const input = document.getElementById('cp-search');
    if (input) { input.value = ''; input.focus(); }
    this._renderPaletteResults(this._commands);

    input?.addEventListener('input', () => {
      this._paletteIndex = 0;
      this._renderPaletteResults(this._filterCommands(input.value));
    });
  }

  closePalette() {
    const overlay = document.getElementById('cyber-command-palette');
    if (overlay) overlay.style.display = 'none';
    this._paletteOpen = false;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Counter Animations
  // ═══════════════════════════════════════════════════════════════════

  /** @private Animate .counter-value elements from 0 to data-count. */
  initCounterAnimations() {
    const counters = document.querySelectorAll('.counter-value');
    if (!counters.length) return;

    const animate = (el) => {
      const target = parseInt(el.dataset.count, 10) || 0;
      const duration = 1500;
      const start = performance.now();

      const step = (now) => {
        const t = Math.min((now - start) / duration, 1);
        // easeOutExpo: 1 - 2^(-10t)
        const ease = t === 1 ? 1 : 1 - Math.pow(2, -10 * t);
        el.textContent = Math.floor(ease * target);
        if (t < 1) requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          animate(entry.target);
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.3 });

    counters.forEach(el => observer.observe(el));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Theme System
  // ═══════════════════════════════════════════════════════════════════

  /** @private Apply saved theme (dark-only for now). */
  initThemeSystem() {
    const theme = localStorage.getItem('eagle-theme') || 'dark';
    document.body.setAttribute('data-theme', theme);
    document.body.classList.add(`${theme}-mode`);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Toast System v2
  // ═══════════════════════════════════════════════════════════════════

  /** @private Enhanced toast notifications with progress bar. */
  initToastSystem() {
    if (!document.getElementById('toast-container')) {
      const c = document.createElement('div');
      c.id = 'toast-container';
      c.style.cssText = 'position:fixed;top:20px;right:20px;z-index:99990;' +
        'display:flex;flex-direction:column;gap:10px;pointer-events:none;';
      document.body.appendChild(c);
    }
    window.showToast = (message, type) => this.showToast(message, type);
  }

  /**
   * Display a toast notification.
   * @param {string} message
   * @param {'success'|'error'|'warning'|'info'} [type='info']
   * @param {number} [duration=5000]
   */
  showToast(message, type = 'info', duration = 5000) {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const colors = { success: '#2ea043', error: '#f85149', warning: '#d29922', info: '#00f0ff' };
    const icons  = { success: '✅', error: '❌', warning: '⚠️', info: 'ℹ️' };
    const color  = colors[type] || colors.info;

    // Enforce max 5 toasts
    while (container.children.length >= 5) container.firstChild.remove();

    const toast = document.createElement('div');
    toast.style.cssText = `pointer-events:auto;position:relative;min-width:280px;max-width:380px;
      padding:14px 38px 14px 16px;background:#161b22;border:1px solid ${color};
      border-radius:8px;color:#c9d1d9;font-size:13px;box-shadow:0 4px 24px rgba(0,0,0,0.4);
      transform:translateX(120%);transition:transform .3s ease;overflow:hidden;`;
    toast.innerHTML = `
      <span style="margin-right:8px;">${icons[type] || icons.info}</span>${message}
      <button style="position:absolute;top:8px;right:10px;background:none;border:none;
        color:#8b949e;cursor:pointer;font-size:14px;" aria-label="Close">✕</button>
      <div style="position:absolute;bottom:0;left:0;height:3px;width:100%;
        background:${color};animation:toast-progress ${duration}ms linear forwards;"></div>`;

    toast.querySelector('button').addEventListener('click', () => this._removeToast(toast));
    container.appendChild(toast);
    requestAnimationFrame(() => { toast.style.transform = 'translateX(0)'; });

    // Inject progress keyframes once
    if (!document.getElementById('toast-kf')) {
      const style = document.createElement('style');
      style.id = 'toast-kf';
      style.textContent = '@keyframes toast-progress{from{width:100%}to{width:0%}}';
      document.head.appendChild(style);
    }

    setTimeout(() => this._removeToast(toast), duration);
  }

  /** @param {HTMLElement} toast */
  _removeToast(toast) {
    if (!toast.parentNode) return;
    toast.style.transform = 'translateX(120%)';
    setTimeout(() => toast.remove(), 300);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Keyboard Shortcuts
  // ═══════════════════════════════════════════════════════════════════

  /** @private Register global keyboard shortcuts. */
  initKeyboardShortcuts() {
    this._keydownHandler = (e) => {
      // Ctrl+K — command palette
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        this._paletteOpen ? this.closePalette() : this.openPalette();
        return;
      }

      // Escape — close palette / modals
      if (e.key === 'Escape') {
        if (this._paletteOpen) { this.closePalette(); return; }
        document.querySelector('.modal-backdrop')?.remove();
        return;
      }

      // Inside palette: arrow nav + enter
      if (this._paletteOpen) {
        const filtered = this._filterCommands(
          document.getElementById('cp-search')?.value || ''
        );
        if (e.key === 'ArrowDown') {
          e.preventDefault();
          this._paletteIndex = Math.min(this._paletteIndex + 1, filtered.length - 1);
          this._renderPaletteResults(filtered);
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          this._paletteIndex = Math.max(this._paletteIndex - 1, 0);
          this._renderPaletteResults(filtered);
        } else if (e.key === 'Enter' && filtered.length) {
          e.preventDefault();
          this._executeCommand(filtered[this._paletteIndex]);
        }
        return;
      }

      // Ctrl+1..4 — switch tabs on first device card
      if ((e.ctrlKey || e.metaKey) && e.key >= '1' && e.key <= '4') {
        e.preventDefault();
        const card = document.querySelector('.device-card');
        if (!card) return;
        const tabs = card.querySelectorAll('.tab-btn');
        const idx = parseInt(e.key, 10) - 1;
        if (tabs[idx]) tabs[idx].click();
        return;
      }

      // ? — show shortcuts help (only outside inputs)
      if (e.key === '?' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName)) {
        this.showToast(
          'Shortcuts: Ctrl+K Command Palette · Ctrl+1-4 Tabs · Esc Close · ? Help',
          'info'
        );
      }
    };
    document.addEventListener('keydown', this._keydownHandler);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Card Effects
  // ═══════════════════════════════════════════════════════════════════

  /** @private Mouse-tracking glow on .device-card and .action-btn. */
  initCardEffects() {
    const handler = (e) => {
      const el = e.target.closest('.device-card, .action-btn');
      if (!el) return;
      const rect = el.getBoundingClientRect();
      el.style.setProperty('--mouse-x', `${e.clientX - rect.left}px`);
      el.style.setProperty('--mouse-y', `${e.clientY - rect.top}px`);
    };
    document.addEventListener('mousemove', handler);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Responsive Menu
  // ═══════════════════════════════════════════════════════════════════

  /** @private Sidebar toggle with hamburger button. */
  initResponsiveMenu() {
    let toggle = document.querySelector('.sidebar-toggle');
    if (!toggle) {
      toggle = document.createElement('button');
      toggle.className = 'sidebar-toggle';
      toggle.setAttribute('aria-label', 'Toggle sidebar');
      toggle.style.cssText = 'position:fixed;top:12px;left:12px;z-index:10100;' +
        'background:#161b22;border:1px solid rgba(0,240,255,0.2);border-radius:6px;' +
        'color:#c9d1d9;font-size:22px;width:38px;height:38px;cursor:pointer;' +
        'display:flex;align-items:center;justify-content:center;';
      toggle.textContent = '☰';
      document.body.appendChild(toggle);
    }

    const collapsed = localStorage.getItem('sidebar-collapsed') === 'true';
    if (collapsed || window.innerWidth < 768) {
      document.body.classList.add('sidebar-collapsed');
      toggle.textContent = '☰';
    }

    toggle.addEventListener('click', () => {
      const isCollapsed = document.body.classList.toggle('sidebar-collapsed');
      toggle.textContent = isCollapsed ? '☰' : '✕';
      localStorage.setItem('sidebar-collapsed', String(isCollapsed));
    });

    // Auto-collapse on mobile
    const onResize = () => {
      if (window.innerWidth < 768 && !document.body.classList.contains('sidebar-collapsed')) {
        document.body.classList.add('sidebar-collapsed');
        toggle.textContent = '☰';
      }
    };
    window.addEventListener('resize', onResize);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Map Integration (Leaflet)
  // ═══════════════════════════════════════════════════════════════════

  /** @private Initialize a dark-themed Leaflet map if #world-map exists. */
  initMapIntegration() {
    const mapEl = document.getElementById('world-map');
    if (!mapEl) return;

    const bootstrap = () => {
      if (typeof L === 'undefined') {
        mapEl.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;' +
          'height:100%;color:#8b949e;font-size:13px;">Map library loading failed.</div>';
        return;
      }
      const map = L.map(mapEl, { zoomControl: false }).setView([20, 0], 2);
      L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://carto.com/">CARTO</a>',
        subdomains: 'abcd', maxZoom: 19
      }).addTo(map);

      let locations = [];
      try { locations = JSON.parse(mapEl.dataset.locations || '[]'); } catch (_) { /* ignore */ }

      const markers = locations.map(loc =>
        L.circleMarker([loc.lat, loc.lng], {
          radius: 6, color: '#00f0ff', fillColor: '#00f0ff',
          fillOpacity: 0.6, weight: 1
        }).addTo(map).bindPopup(`Device ${loc.id || ''}`)
      );

      if (markers.length) {
        map.fitBounds(L.featureGroup(markers).getBounds().pad(0.3));
      }
    };

    if (typeof L !== 'undefined') { bootstrap(); return; }

    // Dynamically load Leaflet 1.9.4
    const css = document.createElement('link');
    css.rel = 'stylesheet';
    css.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
    document.head.appendChild(css);

    const js = document.createElement('script');
    js.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
    js.onload = bootstrap;
    js.onerror = () => {
      mapEl.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;' +
        'height:100%;color:#8b949e;font-size:13px;">Could not load Leaflet.</div>';
    };
    document.head.appendChild(js);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  Scan Line Effect
  // ═══════════════════════════════════════════════════════════════════

  /** @private Subtle animated scan line overlay. */
  initScanLineEffect() {
    if (document.querySelector('.cyber-scan-line')) return;
    const line = document.createElement('div');
    line.className = 'cyber-scan-line';
    line.style.cssText = 'position:fixed;left:0;width:100%;height:2px;z-index:99998;' +
      'background:linear-gradient(90deg,transparent,rgba(0,240,255,0.03),transparent);' +
      'pointer-events:none;animation:cyber-scan 8s linear infinite;top:0;';
    document.body.appendChild(line);

    if (!document.getElementById('cyber-scan-kf')) {
      const style = document.createElement('style');
      style.id = 'cyber-scan-kf';
      style.textContent = '@keyframes cyber-scan{0%{top:0}100%{top:100vh}}';
      document.head.appendChild(style);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Global helpers (backwards-compatible)
// ═══════════════════════════════════════════════════════════════════════

/** @param {HTMLElement} btn  @param {string} paneId */
window.switchTab = function (btn, paneId) {
  const card = btn.closest('.device-card');
  if (!card) return;
  card.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  card.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
  btn.classList.add('active');
  const pane = document.getElementById(paneId);
  if (pane) pane.classList.add('active');
};

/** @param {string} message  @param {Function} callback */
window.confirmAction = function (message, callback) {
  if (typeof window.showModal === 'function') {
    window.showModal({
      title: 'Confirm Action',
      message: message || 'Are you sure you want to proceed?',
      type: 'confirm',
      confirmText: 'Yes, Continue',
      cancelText: 'Cancel',
      onConfirm: callback
    });
  } else if (confirm(message || 'Are you sure?')) {
    callback();
  }
};

// ═══════════════════════════════════════════════════════════════════════
//  Initialization
// ═══════════════════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  window.cyberDashboard = new CyberDashboard();
});

// Handle Turbolinks page transitions
if (typeof Turbolinks !== 'undefined') {
  document.addEventListener('turbolinks:load', () => {
    window.cyberDashboard = new CyberDashboard();
  });
}
