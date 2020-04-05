require "application_system_test_case"

class ApkInstallationsTest < ApplicationSystemTestCase
  setup do
    @apk_installation = apk_installations(:one)
  end

  test "visiting the index" do
    visit apk_installations_url
    assert_selector "h1", text: "Apk Installations"
  end

  test "creating a Apk installation" do
    visit apk_installations_url
    click_on "New Apk Installation"

    fill_in "Apk payload", with: @apk_installation.apk_payload_id
    fill_in "Status", with: @apk_installation.status
    fill_in "Taget ip", with: @apk_installation.taget_ip
    click_on "Create Apk installation"

    assert_text "Apk installation was successfully created"
    click_on "Back"
  end

  test "updating a Apk installation" do
    visit apk_installations_url
    click_on "Edit", match: :first

    fill_in "Apk payload", with: @apk_installation.apk_payload_id
    fill_in "Status", with: @apk_installation.status
    fill_in "Taget ip", with: @apk_installation.taget_ip
    click_on "Update Apk installation"

    assert_text "Apk installation was successfully updated"
    click_on "Back"
  end

  test "destroying a Apk installation" do
    visit apk_installations_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Apk installation was successfully destroyed"
  end
end
