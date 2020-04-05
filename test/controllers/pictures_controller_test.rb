require 'test_helper'

class PicturesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @picture = pictures(:one)
  end

  test "should get index" do
    get pictures_url
    assert_response :success
  end

  test "should get new" do
    get new_picture_url
    assert_response :success
  end

  test "should create picture" do
    assert_difference('Picture.count') do
      post pictures_url, params: { picture: { date: @picture.date, duration: @picture.duration, filename: @picture.filename, smartphone_id: @picture.smartphone_id } }
    end

    assert_redirected_to picture_url(Picture.last)
  end

  test "should show picture" do
    get picture_url(@picture)
    assert_response :success
  end

  test "should get edit" do
    get edit_picture_url(@picture)
    assert_response :success
  end

  test "should update picture" do
    patch picture_url(@picture), params: { picture: { date: @picture.date, duration: @picture.duration, filename: @picture.filename, smartphone_id: @picture.smartphone_id } }
    assert_redirected_to picture_url(@picture)
  end

  test "should destroy picture" do
    assert_difference('Picture.count', -1) do
      delete picture_url(@picture)
    end

    assert_redirected_to pictures_url
  end
end
