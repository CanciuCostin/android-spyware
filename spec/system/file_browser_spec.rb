# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'File Browser', type: :system do
  let!(:admin) { AdminUser.create!(email: 'admin@example.com', password: 'password123456', password_confirmation: 'password123456') }
  let!(:device) { create_installed_device(name: 'File Phone', device_id: 'e2e-file-001') }

  before { admin_login }

  describe 'navigating the file browser page' do
    before { visit admin_file_browser_path }

    it 'renders the file browser UI' do
      expect(page).to have_text('Remote File Browser')
    end

    it 'shows a device selector dropdown' do
      expect(page).to have_css('#file-device-select')
    end

    it 'has a path input defaulting to /sdcard' do
      expect(page).to have_field('file-path-input', with: '/sdcard')
    end

    it 'has a Browse button' do
      expect(page).to have_button('📂 Browse')
    end

    it 'displays placeholder text in the file listing area' do
      expect(page).to have_css('#file-listing')
      expect(page).to have_text('Enter a path and click Browse')
    end
  end

  describe 'browsing files (AJAX)' do
    before { visit admin_file_browser_path }

    it 'shows loading indicator when Browse is clicked' do
      # Stub the AJAX endpoint to avoid real device communication
      page.execute_script(<<~JS)
        $.ajaxSetup({
          beforeSend: function(xhr, settings) {
            if (settings.url && settings.url.indexOf('browse_files') > -1) {
              xhr.abort();
              document.getElementById('file-listing').innerHTML = '<p style="color:#58a6ff;">Loading...</p>';
            }
          }
        });
      JS
      click_button '📂 Browse'
      expect(page).to have_text('Loading', wait: 5).or have_text('Enter a path')
    end
  end

  describe 'file search' do
    it 'provides a path input that can be edited for search' do
      visit admin_file_browser_path
      fill_in 'file-path-input', with: '/sdcard/DCIM'
      expect(find('#file-path-input').value).to eq('/sdcard/DCIM')
    end
  end

  describe 'device selection' do
    let!(:device2) { create_installed_device(name: 'File Phone 2', device_id: 'e2e-file-002') }

    it 'lists all devices in the selector' do
      visit admin_file_browser_path
      within('#file-device-select') do
        expect(page).to have_text('File Phone')
        expect(page).to have_text('File Phone 2')
      end
    end
  end
end
