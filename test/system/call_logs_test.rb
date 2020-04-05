require "application_system_test_case"

class CallLogsTest < ApplicationSystemTestCase
  setup do
    @call_log = call_logs(:one)
  end

  test "visiting the index" do
    visit call_logs_url
    assert_selector "h1", text: "Call Logs"
  end

  test "creating a Call log" do
    visit call_logs_url
    click_on "New Call Log"

    fill_in "Date", with: @call_log.date
    fill_in "Destination", with: @call_log.destination
    fill_in "Duration", with: @call_log.duration
    fill_in "Filename", with: @call_log.filename
    fill_in "Smartphone", with: @call_log.smartphone_id
    fill_in "Source", with: @call_log.source
    click_on "Create Call log"

    assert_text "Call log was successfully created"
    click_on "Back"
  end

  test "updating a Call log" do
    visit call_logs_url
    click_on "Edit", match: :first

    fill_in "Date", with: @call_log.date
    fill_in "Destination", with: @call_log.destination
    fill_in "Duration", with: @call_log.duration
    fill_in "Filename", with: @call_log.filename
    fill_in "Smartphone", with: @call_log.smartphone_id
    fill_in "Source", with: @call_log.source
    click_on "Update Call log"

    assert_text "Call log was successfully updated"
    click_on "Back"
  end

  test "destroying a Call log" do
    visit call_logs_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Call log was successfully destroyed"
  end
end
