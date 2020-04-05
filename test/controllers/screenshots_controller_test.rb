require 'test_helper'

class ScreenshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @screenshot = screenshots(:one)
  end

  test "should get index" do
    get screenshots_url
    assert_response :success
  end

  test "should get new" do
    get new_screenshot_url
    assert_response :success
  end

  test "should create screenshot" do
    assert_difference('Screenshot.count') do
      post screenshots_url, params: { screenshot: { date: @screenshot.date, duration: @screenshot.duration, filename: @screenshot.filename, smartphone_id: @screenshot.smartphone_id } }
    end

    assert_redirected_to screenshot_url(Screenshot.last)
  end

  test "should show screenshot" do
    get screenshot_url(@screenshot)
    assert_response :success
  end

  test "should get edit" do
    get edit_screenshot_url(@screenshot)
    assert_response :success
  end

  test "should update screenshot" do
    patch screenshot_url(@screenshot), params: { screenshot: { date: @screenshot.date, duration: @screenshot.duration, filename: @screenshot.filename, smartphone_id: @screenshot.smartphone_id } }
    assert_redirected_to screenshot_url(@screenshot)
  end

  test "should destroy screenshot" do
    assert_difference('Screenshot.count', -1) do
      delete screenshot_url(@screenshot)
    end

    assert_redirected_to screenshots_url
  end
end
