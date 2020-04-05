require 'test_helper'

class ApkPayloadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @apk_payload = apk_payloads(:one)
  end

  test "should get index" do
    get apk_payloads_url
    assert_response :success
  end

  test "should get new" do
    get new_apk_payload_url
    assert_response :success
  end

  test "should create apk_payload" do
    assert_difference('ApkPayload.count') do
      post apk_payloads_url, params: { apk_payload: { destination_ip: @apk_payload.destination_ip, destination_port: @apk_payload.destination_port, forwarding_ip: @apk_payload.forwarding_ip, forwarding_port: @apk_payload.forwarding_port } }
    end

    assert_redirected_to apk_payload_url(ApkPayload.last)
  end

  test "should show apk_payload" do
    get apk_payload_url(@apk_payload)
    assert_response :success
  end

  test "should get edit" do
    get edit_apk_payload_url(@apk_payload)
    assert_response :success
  end

  test "should update apk_payload" do
    patch apk_payload_url(@apk_payload), params: { apk_payload: { destination_ip: @apk_payload.destination_ip, destination_port: @apk_payload.destination_port, forwarding_ip: @apk_payload.forwarding_ip, forwarding_port: @apk_payload.forwarding_port } }
    assert_redirected_to apk_payload_url(@apk_payload)
  end

  test "should destroy apk_payload" do
    assert_difference('ApkPayload.count', -1) do
      delete apk_payload_url(@apk_payload)
    end

    assert_redirected_to apk_payloads_url
  end
end
