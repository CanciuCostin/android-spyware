require "application_system_test_case"

class SmartphonesTest < ApplicationSystemTestCase
  setup do
    @smartphone = smartphones(:one)
  end

  test "visiting the index" do
    visit smartphones_url
    assert_selector "h1", text: "Smartphones"
  end

  test "creating a Smartphone" do
    visit smartphones_url
    click_on "New Smartphone"

    fill_in "Call logs", with: @smartphone.call_logs
    fill_in "Contacts", with: @smartphone.contacts
    fill_in "Geo locations", with: @smartphone.geo_locations
    fill_in "Is app hidden", with: @smartphone.is_app_hidden
    fill_in "Is rooted", with: @smartphone.is_rooted
    fill_in "Name", with: @smartphone.name
    fill_in "Operating system", with: @smartphone.operating_system
    fill_in "Pictures", with: @smartphone.pictures
    fill_in "Recordings", with: @smartphone.recordings
    fill_in "Screenshots", with: @smartphone.screenshots
    fill_in "Sms messages", with: @smartphone.sms_messages
    fill_in "Videos", with: @smartphone.videos
    click_on "Create Smartphone"

    assert_text "Smartphone was successfully created"
    click_on "Back"
  end

  test "updating a Smartphone" do
    visit smartphones_url
    click_on "Edit", match: :first

    fill_in "Call logs", with: @smartphone.call_logs
    fill_in "Contacts", with: @smartphone.contacts
    fill_in "Geo locations", with: @smartphone.geo_locations
    fill_in "Is app hidden", with: @smartphone.is_app_hidden
    fill_in "Is rooted", with: @smartphone.is_rooted
    fill_in "Name", with: @smartphone.name
    fill_in "Operating system", with: @smartphone.operating_system
    fill_in "Pictures", with: @smartphone.pictures
    fill_in "Recordings", with: @smartphone.recordings
    fill_in "Screenshots", with: @smartphone.screenshots
    fill_in "Sms messages", with: @smartphone.sms_messages
    fill_in "Videos", with: @smartphone.videos
    click_on "Update Smartphone"

    assert_text "Smartphone was successfully updated"
    click_on "Back"
  end

  test "destroying a Smartphone" do
    visit smartphones_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Smartphone was successfully destroyed"
  end
end
