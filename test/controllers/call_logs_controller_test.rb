require 'test_helper'

class CallLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @call_log = call_logs(:one)
  end

  test "should get index" do
    get call_logs_url
    assert_response :success
  end

  test "should get new" do
    get new_call_log_url
    assert_response :success
  end

  test "should create call_log" do
    assert_difference('CallLog.count') do
      post call_logs_url, params: { call_log: { date: @call_log.date, destination: @call_log.destination, duration: @call_log.duration, filename: @call_log.filename, smartphone_id: @call_log.smartphone_id, source: @call_log.source } }
    end

    assert_redirected_to call_log_url(CallLog.last)
  end

  test "should show call_log" do
    get call_log_url(@call_log)
    assert_response :success
  end

  test "should get edit" do
    get edit_call_log_url(@call_log)
    assert_response :success
  end

  test "should update call_log" do
    patch call_log_url(@call_log), params: { call_log: { date: @call_log.date, destination: @call_log.destination, duration: @call_log.duration, filename: @call_log.filename, smartphone_id: @call_log.smartphone_id, source: @call_log.source } }
    assert_redirected_to call_log_url(@call_log)
  end

  test "should destroy call_log" do
    assert_difference('CallLog.count', -1) do
      delete call_log_url(@call_log)
    end

    assert_redirected_to call_logs_url
  end
end
