require 'test_helper'

class ApkInstallationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @apk_installation = apk_installations(:one)
  end

  test "should get index" do
    get apk_installations_url
    assert_response :success
  end

  test "should get new" do
    get new_apk_installation_url
    assert_response :success
  end

  test "should create apk_installation" do
    assert_difference('ApkInstallation.count') do
      post apk_installations_url, params: { apk_installation: { apk_payload_id: @apk_installation.apk_payload_id, status: @apk_installation.status, taget_ip: @apk_installation.taget_ip } }
    end

    assert_redirected_to apk_installation_url(ApkInstallation.last)
  end

  test "should show apk_installation" do
    get apk_installation_url(@apk_installation)
    assert_response :success
  end

  test "should get edit" do
    get edit_apk_installation_url(@apk_installation)
    assert_response :success
  end

  test "should update apk_installation" do
    patch apk_installation_url(@apk_installation), params: { apk_installation: { apk_payload_id: @apk_installation.apk_payload_id, status: @apk_installation.status, taget_ip: @apk_installation.taget_ip } }
    assert_redirected_to apk_installation_url(@apk_installation)
  end

  test "should destroy apk_installation" do
    assert_difference('ApkInstallation.count', -1) do
      delete apk_installation_url(@apk_installation)
    end

    assert_redirected_to apk_installations_url
  end
end
