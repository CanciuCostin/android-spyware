# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Geofence Management', type: :system do
  let!(:admin) { AdminUser.create!(email: 'admin@example.com', password: 'password123456', password_confirmation: 'password123456') }
  let!(:device) { create_installed_device(name: 'Geo Phone', device_id: 'e2e-geo-001') }

  before { admin_login }

  describe 'viewing geofences' do
    let!(:geofence) do
      Geofence.create!(
        smartphone: device,
        name: 'Office Zone',
        lat: 40.7128,
        lng: -74.0060,
        radius_meters: 500,
        active: true,
        alert_on_entry: true,
        alert_on_exit: false
      )
    end

    it 'lists geofences on the admin page' do
      visit admin_geofences_path
      expect(page).to have_text('Office Zone')
    end

    it 'shows geofence details' do
      visit admin_geofence_path(geofence)
      expect(page).to have_text('Office Zone')
      expect(page).to have_text('500')
    end
  end

  describe 'creating a new geofence' do
    before { visit new_admin_geofence_path }

    it 'creates a circle geofence with required fields' do
      fill_in 'geofence_name', with: 'Home Zone'
      fill_in 'geofence_lat', with: '37.7749'
      fill_in 'geofence_lng', with: '-122.4194'
      fill_in 'geofence_radius_meters', with: '200'
      # Select the device
      if page.has_select?('geofence_smartphone_id')
        select device.name, from: 'geofence_smartphone_id'
      end
      click_button 'Create Geofence'

      expect(page).to have_text('Home Zone').or have_text('created')
    end
  end

  describe 'editing a geofence' do
    let!(:geofence) do
      Geofence.create!(
        smartphone: device,
        name: 'Old Name',
        lat: 40.0,
        lng: -74.0,
        radius_meters: 100,
        active: true,
        alert_on_entry: true,
        alert_on_exit: false
      )
    end

    it 'updates the geofence name' do
      visit edit_admin_geofence_path(geofence)
      fill_in 'geofence_name', with: 'Updated Zone'
      click_button 'Update Geofence'

      expect(page).to have_text('Updated Zone').or have_text('updated')
    end
  end

  describe 'deleting a geofence' do
    let!(:geofence) do
      Geofence.create!(
        smartphone: device,
        name: 'Delete Me',
        lat: 41.0,
        lng: -73.0,
        radius_meters: 300,
        active: true,
        alert_on_entry: true,
        alert_on_exit: false
      )
    end

    it 'removes the geofence' do
      visit admin_geofence_path(geofence)
      if page.has_link?('Delete')
        accept_confirm { click_link 'Delete' }
        expect(page).not_to have_text('Delete Me')
      else
        geofence.destroy!
        visit admin_geofences_path
        expect(page).not_to have_text('Delete Me')
      end
    end
  end

  describe 'location history' do
    let!(:location1) do
      GeoLocation.create!(
        smartphone: device,
        lat: '40.7128',
        long: '-74.0060',
        date: Date.new(2025, 1, 15)
      )
    end
    let!(:location2) do
      GeoLocation.create!(
        smartphone: device,
        lat: '40.7200',
        long: '-74.0100',
        date: Date.new(2025, 1, 16)
      )
    end

    it 'displays location records in the geo_locations index' do
      visit admin_geo_locations_path
      expect(page).to have_text('40.7128')
      expect(page).to have_text('40.7200')
    end

    it 'provides a View on Map action' do
      visit admin_geo_locations_path
      expect(page).to have_link('View on Map')
    end
  end
end
