/**
 * EagleSpy V5 - Modern Dashboard JavaScript
 * Theme toggle, toast notifications, modals, responsive behavior
 */

class ModernDashboard {
  constructor() {
    this.init();
  }

  init() {
    this.initThemeToggle();
    this.initToastSystem();
    this.initModals();
    this.initResponsiveMenu();
    this.initSmoothTransitions();
    this.initCardGlow();
    this.initOptimisticUI();
  }

  // ─── Theme Toggle with localStorage persistence ───
  initThemeToggle() {
    const savedTheme = localStorage.getItem('eagle-theme') || 'dark';
    document.body.classList.add(`${savedTheme}-mode`);
    document.body.setAttribute('data-theme', savedTheme);

    // Create toggle if it doesn't exist
    if (!document.querySelector('.theme-toggle')) {
      const toggle = document.createElement('div');
      toggle.className = 'theme-toggle';
      toggle.innerHTML = `
        <div class="toggle-option ${savedTheme === 'dark' ? 'active' : ''}" data-theme="dark">
          🌙
        </div>
        <div class="toggle-option ${savedTheme === 'light' ? 'active' : ''}" data-theme="light">
          ☀️
        </div>
      `;
      document.body.appendChild(toggle);

      toggle.addEventListener('click', (e) => {
        const option = e.target.closest('.toggle-option');
        if (!option) return;

        const newTheme = option.dataset.theme;
        this.setTheme(newTheme);
      });
    }
  }

  setTheme(theme) {
    // Disable transitions temporarily
    document.body.classList.add('theme-transitioning');

    // Remove old theme classes
    document.body.classList.remove('light-mode', 'dark-mode');
    document.querySelector('.theme-toggle .toggle-option.active')?.classList.remove('active');

    // Apply new theme
    document.body.classList.add(`${theme}-mode`);
    document.body.setAttribute('data-theme', theme);
    document.querySelector(`.theme-toggle .toggle-option[data-theme="${theme}"]`)?.classList.add('active');

    // Save to localStorage
    localStorage.setItem('eagle-theme', theme);

    // Re-enable transitions
    setTimeout(() => {
      document.body.classList.remove('theme-transitioning');
    }, 50);

    this.showToast(`Switched to ${theme} mode`, 'success');
  }

  // ─── Toast Notification System ───
  initToastSystem() {
    if (!document.getElementById('toast-container')) {
      const container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    // Expose global toast function
    window.showToast = (message, type = 'info', duration = 5000) => {
      this.showToast(message, type, duration);
    };

    // Listen for AJAX events
    this.setupAjaxToasts();
  }

  showToast(message, type = 'info', duration = 5000) {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const icons = {
      success: '✅',
      error: '❌',
      warning: '⚠️',
      info: 'ℹ️'
    };

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <span class="toast-icon">${icons[type] || icons.info}</span>
      <div class="toast-content">
        <div class="toast-message">${message}</div>
      </div>
      <button class="toast-close" aria-label="Close">✕</button>
      ${duration > 0 ? '<div class="toast-progress"></div>' : ''}
    `;

    const closeBtn = toast.querySelector('.toast-close');
    closeBtn.addEventListener('click', () => this.removeToast(toast));

    container.appendChild(toast);

    // Auto-dismiss
    if (duration > 0) {
      setTimeout(() => this.removeToast(toast), duration);
    }

    return toast;
  }

  removeToast(toast) {
    toast.classList.add('toast-exit');
    setTimeout(() => toast.remove(), 200);
  }

  setupAjaxToasts() {
    document.addEventListener('ajax:success', (e) => {
      const response = e.detail && e.detail[0];
      let message = 'Command sent successfully';
      
      if (response && typeof response === 'string' && response.length < 200) {
        message = response;
      } else if (response && response.message) {
        message = response.message;
      }
      
      this.showToast(message, 'success');
    });

    document.addEventListener('ajax:error', (e) => {
      const response = e.detail && e.detail[0];
      let message = 'Command failed';
      
      if (response && response.error) {
        message = response.error;
      }
      
      this.showToast(message, 'error');
    });

    document.addEventListener('ajax:send', () => {
      // Show loading state on buttons
      const activeElement = document.activeElement;
      if (activeElement && (activeElement.tagName === 'BUTTON' || activeElement.tagName === 'A')) {
        activeElement.classList.add('btn-loading');
      }
    });

    document.addEventListener('ajax:complete', () => {
      // Remove loading state
      document.querySelectorAll('.btn-loading').forEach(btn => {
        btn.classList.remove('btn-loading');
      });
    });
  }

  // ─── Modal System ───
  initModals() {
    window.showModal = (options) => this.showModal(options);
    window.hideModal = () => this.hideModal();

    // Handle ESC key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideModal();
      }
    });
  }

  showModal(options) {
    const {
      title = 'Confirm',
      message = 'Are you sure?',
      type = 'confirm',
      confirmText = 'Confirm',
      cancelText = 'Cancel',
      onConfirm = () => {},
      onCancel = () => {}
    } = options;

    // Remove existing modal
    this.hideModal();

    const backdrop = document.createElement('div');
    backdrop.className = 'modal-backdrop';
    backdrop.innerHTML = `
      <div class="modal ${type === 'confirm' ? 'modal-confirm' : ''}">
        <div class="modal-header">
          <h3 class="modal-title">${title}</h3>
          <button class="modal-close" aria-label="Close">✕</button>
        </div>
        <div class="modal-body">
          <p>${message}</p>
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary modal-cancel">${cancelText}</button>
          <button class="btn ${type === 'confirm' ? 'btn-danger' : 'btn-primary'} modal-confirm-btn">${confirmText}</button>
        </div>
      </div>
    `;

    document.body.appendChild(backdrop);

    // Event listeners
    const modal = backdrop.querySelector('.modal');
    const closeBtn = backdrop.querySelector('.modal-close');
    const cancelBtn = backdrop.querySelector('.modal-cancel');
    const confirmBtn = backdrop.querySelector('.modal-confirm-btn');

    const close = () => {
      this.hideModal();
      onCancel();
    };

    const confirm = () => {
      this.hideModal();
      onConfirm();
    };

    backdrop.addEventListener('click', (e) => {
      if (e.target === backdrop) close();
    });

    closeBtn.addEventListener('click', close);
    cancelBtn.addEventListener('click', close);
    confirmBtn.addEventListener('click', confirm);

    // Focus trap
    confirmBtn.focus();
  }

  hideModal() {
    const backdrop = document.querySelector('.modal-backdrop');
    if (backdrop) {
      backdrop.style.opacity = '0';
      setTimeout(() => backdrop.remove(), 200);
    }
  }

  // ─── Responsive Mobile Menu ───
  initResponsiveMenu() {
    const toggle = document.querySelector('.sidebar-toggle');
    if (!toggle) return;

    toggle.addEventListener('click', () => {
      document.body.classList.toggle('sidebar-open');
      document.body.classList.toggle('sidebar-collapsed');
      toggle.classList.toggle('is-active');
    });

    // Close sidebar on mobile when clicking outside
    document.addEventListener('click', (e) => {
      if (window.innerWidth <= 768) {
        if (!e.target.closest('.header#header') && 
            !e.target.closest('.sidebar-toggle') &&
            document.body.classList.contains('sidebar-open')) {
          document.body.classList.remove('sidebar-open');
          document.body.classList.add('sidebar-collapsed');
          toggle.classList.remove('is-active');
        }
      }
    });

    // Auto-collapse sidebar on mobile
    this.handleResponsiveSidebar();
    window.addEventListener('resize', () => this.handleResponsiveSidebar());
  }

  handleResponsiveSidebar() {
    if (window.innerWidth <= 768) {
      document.body.classList.add('sidebar-collapsed');
      document.body.classList.remove('sidebar-open');
      document.querySelector('.sidebar-toggle')?.classList.remove('is-active');
    }
  }

  // ─── Smooth Transitions ───
  initSmoothTransitions() {
    // Disable transitions on load
    window.addEventListener('load', () => {
      document.body.classList.remove('theme-transitioning');
    });

    // Add smooth scroll
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');
        if (href === '#') return;
        
        e.preventDefault();
        const target = document.querySelector(href);
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });
    });
  }

  // ─── Card Glow Effect ───
  initCardGlow() {
    document.querySelectorAll('.card-glow').forEach(card => {
      card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width) * 100;
        const y = ((e.clientY - rect.top) / rect.height) * 100;
        card.style.setProperty('--mouse-x', `${x}%`);
        card.style.setProperty('--mouse-y', `${y}%`);
      });
    });
  }

  // ─── Optimistic UI Updates ───
  initOptimisticUI() {
    document.addEventListener('click', (e) => {
      const link = e.target.closest('a[data-remote="true"]');
      if (!link) return;

      // Add optimistic update class to parent card
      const card = link.closest('.device-card, .action-btn, .stat-card');
      if (card) {
        card.classList.add('optimistic-update');
        
        // Remove on success
        document.addEventListener('ajax:success', () => {
          card.classList.remove('optimistic-update');
          card.classList.add('update-success');
          setTimeout(() => card.classList.remove('update-success'), 300);
        }, { once: true });

        // Show error on failure
        document.addEventListener('ajax:error', () => {
          card.classList.remove('optimistic-update');
          card.classList.add('update-error');
          setTimeout(() => card.classList.remove('update-error'), 400);
        }, { once: true });
      }
    });
  }

  // ─── Utility: Detect scroll ───
  detectScroll(element) {
    if (element.scrollWidth > element.clientWidth) {
      element.classList.add('has-scroll');
    } else {
      element.classList.remove('has-scroll');
    }
  }
}

// ─── Tab Switching (for dashboard device cards) ───
window.switchTab = function(btn, paneId) {
  const card = btn.closest('.device-card');
  if (!card) return;

  card.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  card.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

  btn.classList.add('active');
  const pane = document.getElementById(paneId);
  if (pane) pane.classList.add('active');
};

// ─── Confirmation for Destructive Actions ───
window.confirmAction = function(message, callback) {
  window.showModal({
    title: 'Confirm Action',
    message: message || 'Are you sure you want to proceed?',
    type: 'confirm',
    confirmText: 'Yes, Continue',
    cancelText: 'Cancel',
    onConfirm: callback
  });
};

// ─── Initialize on DOM ready ───
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    new ModernDashboard();
  });
} else {
  new ModernDashboard();
}

// Re-initialize on Turbolinks navigation
document.addEventListener('turbolinks:load', () => {
  new ModernDashboard();
});
