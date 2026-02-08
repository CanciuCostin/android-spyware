module Api
  class AppUsageController < Api::BaseController

    def receive
      device_id = params[:device_id]
      return head :bad_request if device_id.blank?

      cache_key = "app_usage:#{device_id}"
      Rails.cache.write(cache_key, {
        app_usage: params[:app_usage] || params[:batch],
        period_days: params[:period_days],
        received_at: Time.current.iso8601
      }, expires_in: 7.days)

      head :ok
    end
  end
end
