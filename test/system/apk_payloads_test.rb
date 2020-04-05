require "application_system_test_case"

class ApkPayloadsTest < ApplicationSystemTestCase
  setup do
    @apk_payload = apk_payloads(:one)
  end

  test "visiting the index" do
    visit apk_payloads_url
    assert_selector "h1", text: "Apk Payloads"
  end

  test "creating a Apk payload" do
    visit apk_payloads_url
    click_on "New Apk Payload"

    fill_in "Destination ip", with: @apk_payload.destination_ip
    fill_in "Destination port", with: @apk_payload.destination_port
    fill_in "Forwarding ip", with: @apk_payload.forwarding_ip
    fill_in "Forwarding port", with: @apk_payload.forwarding_port
    click_on "Create Apk payload"

    assert_text "Apk payload was successfully created"
    click_on "Back"
  end

  test "updating a Apk payload" do
    visit apk_payloads_url
    click_on "Edit", match: :first

    fill_in "Destination ip", with: @apk_payload.destination_ip
    fill_in "Destination port", with: @apk_payload.destination_port
    fill_in "Forwarding ip", with: @apk_payload.forwarding_ip
    fill_in "Forwarding port", with: @apk_payload.forwarding_port
    click_on "Update Apk payload"

    assert_text "Apk payload was successfully updated"
    click_on "Back"
  end

  test "destroying a Apk payload" do
    visit apk_payloads_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Apk payload was successfully destroyed"
  end
end
