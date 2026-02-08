# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Analytics Dashboard', type: :system do
  let!(:admin) { AdminUser.create!(email: 'admin@example.com', password: 'password123456', password_confirmation: 'password123456') }

  before { admin_login }

  context 'when no devices exist' do
    it 'shows the empty state' do
      visit admin_analytics_path
      expect(page).to have_text('No Devices Available')
    end
  end

  context 'when devices exist' do
    let!(:device) { create_installed_device(name: 'Analytics Phone', device_id: 'e2e-analytics-001') }

    before { visit admin_analytics_path }

    describe 'page structure' do
      it 'renders the analytics dashboard title' do
        expect(page).to have_text('Analytics Dashboard')
      end

      it 'shows the device selector dropdown' do
        expect(page).to have_css('#device-select')
      end

      it 'includes the selected device in the dropdown' do
        within('#device-select') do
          expect(page).to have_text('Analytics Phone')
        end
      end
    end

    describe 'date range selector' do
      it 'renders date range buttons' do
        expect(page).to have_button('Last 7 Days')
        expect(page).to have_button('Last 30 Days')
        expect(page).to have_button('Last 90 Days')
      end

      it 'has "Last 7 Days" as the default active range' do
        btn = find('.date-range-btn', text: 'Last 7 Days')
        expect(btn[:class]).to include('active')
      end

      it 'switches the active date range on click' do
        click_button 'Last 30 Days'
        btn30 = find('.date-range-btn', text: 'Last 30 Days')
        btn7 = find('.date-range-btn', text: 'Last 7 Days')
        expect(btn30[:class]).to include('active')
        expect(btn7[:class]).not_to include('active')
      end

      it 'shows a custom date picker input' do
        expect(page).to have_css('#custom-date-picker')
      end
    end

    describe 'chart containers' do
      it 'renders the Activity Timeline chart canvas' do
        expect(page).to have_css('#activity-timeline-chart')
      end

      it 'renders the App Usage chart canvas' do
        expect(page).to have_css('#app-usage-chart')
      end

      it 'renders the Call & SMS chart canvas' do
        expect(page).to have_css('#call-sms-chart')
      end

      it 'renders the Battery & Network chart canvas' do
        expect(page).to have_css('#battery-network-chart')
      end

      it 'renders the Location Heatmap container' do
        expect(page).to have_css('#location-heatmap')
      end
    end

    describe 'export functionality' do
      it 'shows Export buttons for charts' do
        expect(page).to have_button('Export ⬇', minimum: 1)
      end

      it 'reveals export menu options when Export is clicked' do
        first('.chart-export-btn').click
        expect(page).to have_css('.export-dropdown.active', wait: 5)
      end

      it 'offers PNG and PDF export options' do
        first('.chart-export-btn').click
        within(first('.export-dropdown.active')) do
          expect(page).to have_button('PNG')
          expect(page).to have_button('PDF')
        end
      end
    end

    describe 'real-time indicator' do
      it 'shows a Live Updates indicator' do
        expect(page).to have_text('Live Updates')
      end
    end
  end

  context 'with multiple devices' do
    let!(:device1) { create_installed_device(name: 'Phone Alpha', device_id: 'e2e-an-001') }
    let!(:device2) { create_installed_device(name: 'Phone Beta', device_id: 'e2e-an-002') }

    it 'lists all devices in the selector' do
      visit admin_analytics_path
      within('#device-select') do
        expect(page).to have_text('Phone Alpha')
        expect(page).to have_text('Phone Beta')
      end
    end
  end
end
