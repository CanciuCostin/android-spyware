require 'test_helper'

class SmsMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sms_message = sms_messages(:one)
  end

  test "should get index" do
    get sms_messages_url
    assert_response :success
  end

  test "should get new" do
    get new_sms_message_url
    assert_response :success
  end

  test "should create sms_message" do
    assert_difference('SmsMessage.count') do
      post sms_messages_url, params: { sms_message: { content: @sms_message.content, date: @sms_message.date, destination: @sms_message.destination, smartphone_id: @sms_message.smartphone_id, source: @sms_message.source } }
    end

    assert_redirected_to sms_message_url(SmsMessage.last)
  end

  test "should show sms_message" do
    get sms_message_url(@sms_message)
    assert_response :success
  end

  test "should get edit" do
    get edit_sms_message_url(@sms_message)
    assert_response :success
  end

  test "should update sms_message" do
    patch sms_message_url(@sms_message), params: { sms_message: { content: @sms_message.content, date: @sms_message.date, destination: @sms_message.destination, smartphone_id: @sms_message.smartphone_id, source: @sms_message.source } }
    assert_redirected_to sms_message_url(@sms_message)
  end

  test "should destroy sms_message" do
    assert_difference('SmsMessage.count', -1) do
      delete sms_message_url(@sms_message)
    end

    assert_redirected_to sms_messages_url
  end
end
