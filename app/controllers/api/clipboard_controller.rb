module Api
  class ClipboardController < Api::BaseController

    def receive
      device_id = params[:device_id]
      
      # Handle batch (offline sync) or single item
      if params[:batch].present? && params[:sync_type] == 'offline_flush'
        process_batch(device_id)
      else
        process_single(device_id)
      end
    end

    private

    def process_single(device_id)
      clipboard_text = params[:clipboard_text]
      timestamp = params[:timestamp]

      return head :bad_request if device_id.blank? || clipboard_text.blank?

      store_clipboard(device_id, clipboard_text, timestamp)

      ActionCable.server.broadcast("clipboard_stream_#{device_id}", {
        device_id: device_id,
        text: clipboard_text,
        timestamp: Time.now.iso8601
      })

      head :ok
    end

    def process_batch(device_id)
      return head :bad_request if device_id.blank?

      batch = params[:batch]
      count = 0

      batch.each do |item|
        text = item[:clipboard_text] || item[:data]
        next if text.blank?
        store_clipboard(device_id, text, item[:timestamp])
        count += 1
      end

      render json: { status: 'batch_received', count: count }
    end

    def store_clipboard(device_id, text, timestamp)
      cache_key = "clipboard:#{device_id}"
      history = Rails.cache.read(cache_key) || []
      history.unshift({
        text: text,
        timestamp: timestamp || Time.now.to_i,
        received_at: Time.now.iso8601
      })
      history = history.first(500)
      Rails.cache.write(cache_key, history, expires_in: 7.days)
    end

  end
end
