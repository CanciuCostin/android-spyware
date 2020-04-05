require "application_system_test_case"

class ScreenshotsTest < ApplicationSystemTestCase
  setup do
    @screenshot = screenshots(:one)
  end

  test "visiting the index" do
    visit screenshots_url
    assert_selector "h1", text: "Screenshots"
  end

  test "creating a Screenshot" do
    visit screenshots_url
    click_on "New Screenshot"

    fill_in "Date", with: @screenshot.date
    fill_in "Duration", with: @screenshot.duration
    fill_in "Filename", with: @screenshot.filename
    fill_in "Smartphone", with: @screenshot.smartphone_id
    click_on "Create Screenshot"

    assert_text "Screenshot was successfully created"
    click_on "Back"
  end

  test "updating a Screenshot" do
    visit screenshots_url
    click_on "Edit", match: :first

    fill_in "Date", with: @screenshot.date
    fill_in "Duration", with: @screenshot.duration
    fill_in "Filename", with: @screenshot.filename
    fill_in "Smartphone", with: @screenshot.smartphone_id
    click_on "Update Screenshot"

    assert_text "Screenshot was successfully updated"
    click_on "Back"
  end

  test "destroying a Screenshot" do
    visit screenshots_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Screenshot was successfully destroyed"
  end
end
