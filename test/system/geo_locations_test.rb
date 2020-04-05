require "application_system_test_case"

class GeoLocationsTest < ApplicationSystemTestCase
  setup do
    @geo_location = geo_locations(:one)
  end

  test "visiting the index" do
    visit geo_locations_url
    assert_selector "h1", text: "Geo Locations"
  end

  test "creating a Geo location" do
    visit geo_locations_url
    click_on "New Geo Location"

    fill_in "Date", with: @geo_location.date
    fill_in "Lat", with: @geo_location.lat
    fill_in "Long", with: @geo_location.long
    fill_in "Smartphone", with: @geo_location.smartphone_id
    click_on "Create Geo location"

    assert_text "Geo location was successfully created"
    click_on "Back"
  end

  test "updating a Geo location" do
    visit geo_locations_url
    click_on "Edit", match: :first

    fill_in "Date", with: @geo_location.date
    fill_in "Lat", with: @geo_location.lat
    fill_in "Long", with: @geo_location.long
    fill_in "Smartphone", with: @geo_location.smartphone_id
    click_on "Update Geo location"

    assert_text "Geo location was successfully updated"
    click_on "Back"
  end

  test "destroying a Geo location" do
    visit geo_locations_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Geo location was successfully destroyed"
  end
end
