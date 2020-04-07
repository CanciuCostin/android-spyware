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

    fill_in "Apk installation", with: @smartphone.apk_installation_id
    fill_in "Created at", with: @smartphone.created_at
    fill_in "Is app hidden", with: @smartphone.is_app_hidden
    fill_in "Is rooted", with: @smartphone.is_rooted
    fill_in "Name", with: @smartphone.name
    fill_in "Operating system", with: @smartphone.operating_system
    fill_in "Updated at", with: @smartphone.updated_at
    click_on "Create Smartphone"

    assert_text "Smartphone was successfully created"
    click_on "Back"
  end

  test "updating a Smartphone" do
    visit smartphones_url
    click_on "Edit", match: :first

    fill_in "Apk installation", with: @smartphone.apk_installation_id
    fill_in "Created at", with: @smartphone.created_at
    fill_in "Is app hidden", with: @smartphone.is_app_hidden
    fill_in "Is rooted", with: @smartphone.is_rooted
    fill_in "Name", with: @smartphone.name
    fill_in "Operating system", with: @smartphone.operating_system
    fill_in "Updated at", with: @smartphone.updated_at
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
