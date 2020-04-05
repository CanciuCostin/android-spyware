require 'test_helper'

class GeoLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @geo_location = geo_locations(:one)
  end

  test "should get index" do
    get geo_locations_url
    assert_response :success
  end

  test "should get new" do
    get new_geo_location_url
    assert_response :success
  end

  test "should create geo_location" do
    assert_difference('GeoLocation.count') do
      post geo_locations_url, params: { geo_location: { date: @geo_location.date, lat: @geo_location.lat, long: @geo_location.long, smartphone_id: @geo_location.smartphone_id } }
    end

    assert_redirected_to geo_location_url(GeoLocation.last)
  end

  test "should show geo_location" do
    get geo_location_url(@geo_location)
    assert_response :success
  end

  test "should get edit" do
    get edit_geo_location_url(@geo_location)
    assert_response :success
  end

  test "should update geo_location" do
    patch geo_location_url(@geo_location), params: { geo_location: { date: @geo_location.date, lat: @geo_location.lat, long: @geo_location.long, smartphone_id: @geo_location.smartphone_id } }
    assert_redirected_to geo_location_url(@geo_location)
  end

  test "should destroy geo_location" do
    assert_difference('GeoLocation.count', -1) do
      delete geo_location_url(@geo_location)
    end

    assert_redirected_to geo_locations_url
  end
end
