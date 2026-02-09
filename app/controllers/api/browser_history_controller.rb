module Api
  class BrowserHistoryController < Api::BaseController

    def receive
      device_id = params[:device_id]
      return head :bad_request if device_id.blank?

      cache_key = "browser_history:#{device_id}"
      Rails.cache.write(cache_key, {
        history: params[:history] || [],
        bookmarks: params[:bookmarks] || [],
        received_at: Time.current.iso8601
      }, expires_in: 7.days)

      head :ok
    end
  end
end
