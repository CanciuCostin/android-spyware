/**
 * EagleSpy V5 - Main Application Entry Point
 *
 * Imports only essential modules eagerly; heavy modules
 * (charts, maps, xterm) are lazy-loaded on demand.
 */
import Rails from '@rails/ujs';
import * as ActiveStorage from '@rails/activestorage';
import * as ActionCable from '@rails/actioncable';
import Turbolinks from 'turbolinks';

import '../stylesheets/application';
import 'channels';

// Core framework init
Rails.start();
ActiveStorage.start();
Turbolinks.start();

// Expose ActionCable globally for ActiveAdmin inline scripts
window.ActionCable = ActionCable;

// ── Lazy-loaded module helpers ──────────────────────────────────────

/**
 * Dynamically import the chart manager when a chart container is present.
 * @returns {Promise<import('../modules/chart_manager')>}
 */
const loadCharts = () => import(/* webpackChunkName: "charts" */ '../modules/chart_manager');

/**
 * Dynamically import xterm when a terminal container is present.
 * @returns {Promise<typeof import('xterm')>}
 */
const loadXterm = () => import(/* webpackChunkName: "xterm" */ 'xterm');

// ── Bootstrap component init on every Turbolinks navigation ─────────

document.addEventListener('turbolinks:load', () => {
  $('[data-toggle="tooltip"]').tooltip();
  $('[data-toggle="popover"]').popover();
  $('[data-toggle="carousel"]').carousel();
  $('[data-toggle="dropdown"]').dropdown();

  // Lazy-load charts when the page has a chart controller
  if (document.querySelector('[data-controller="charts"]')) {
    loadCharts().then(({ default: chartManager }) => {
      window.chartManager = chartManager;
    });
  }

  // Lazy-load xterm when a terminal element is present
  if (document.getElementById('terminal-container')) {
    loadXterm();
  }
});
