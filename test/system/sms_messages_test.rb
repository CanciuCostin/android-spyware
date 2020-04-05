require "application_system_test_case"

class SmsMessagesTest < ApplicationSystemTestCase
  setup do
    @sms_message = sms_messages(:one)
  end

  test "visiting the index" do
    visit sms_messages_url
    assert_selector "h1", text: "Sms Messages"
  end

  test "creating a Sms message" do
    visit sms_messages_url
    click_on "New Sms Message"

    fill_in "Content", with: @sms_message.content
    fill_in "Date", with: @sms_message.date
    fill_in "Destination", with: @sms_message.destination
    fill_in "Smartphone", with: @sms_message.smartphone_id
    fill_in "Source", with: @sms_message.source
    click_on "Create Sms message"

    assert_text "Sms message was successfully created"
    click_on "Back"
  end

  test "updating a Sms message" do
    visit sms_messages_url
    click_on "Edit", match: :first

    fill_in "Content", with: @sms_message.content
    fill_in "Date", with: @sms_message.date
    fill_in "Destination", with: @sms_message.destination
    fill_in "Smartphone", with: @sms_message.smartphone_id
    fill_in "Source", with: @sms_message.source
    click_on "Update Sms message"

    assert_text "Sms message was successfully updated"
    click_on "Back"
  end

  test "destroying a Sms message" do
    visit sms_messages_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Sms message was successfully destroyed"
  end
end
