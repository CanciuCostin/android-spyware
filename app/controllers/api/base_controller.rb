require 'openssl'

module Api
  class BaseController < ApplicationController
    include Api::SmartphoneFinder
    
    skip_before_action :verify_authenticity_token
    before_action :authenticate_device!
    respond_to :json
    
    def authenticate_device!
      device_id = extract_device_id
      return unless device_id

      expected_token = device_auth_token

      if expected_token.blank?
        Rails.logger.error('[API::BaseController] Missing device authentication token configuration')
        render json: { error: 'Service unavailable. Token not configured.' }, status: :service_unavailable
        return
      end

      if signature_present?
        return if valid_signature?(device_id, expected_token)

        Rails.logger.warn('[API::BaseController] Device signature validation failed')
        render json: { error: 'Unauthorized. Invalid signature.' }, status: :unauthorized
      else
        provided_token = (request.headers['X-Device-Token'] || params[:token]).to_s
        unless secure_compare(provided_token, expected_token)
          Rails.logger.warn('[API::BaseController] Device token validation failed (legacy path)')
          render json: { error: 'Unauthorized. Invalid token.' }, status: :unauthorized
        end
      end
    end

    private

    def signature_present?
      request.headers['X-Device-Signature'].present? && request.headers['X-Device-Timestamp'].present?
    end

    def valid_signature?(device_id, secret)
      timestamp = request.headers['X-Device-Timestamp'].to_s
      signature = request.headers['X-Device-Signature'].to_s

      return false unless timestamp_valid?(timestamp)

      payload = [device_id, timestamp].join(':')
      expected = OpenSSL::HMAC.hexdigest('sha256', secret, payload)
      secure_compare(signature, expected)
    end

    def timestamp_valid?(timestamp)
      return false if timestamp.blank?
      ts = Time.at(timestamp.to_i)
      skew = (ENV['DEVICE_SIGNATURE_SKEW_SECONDS'].presence || 300).to_i
      (Time.current - skew)..(Time.current + skew) === ts
    rescue StandardError
      false
    end

    def extract_device_id
      device_id = sanitize_device_id(request.headers['X-Device-ID'] || params[:device_id])
      if device_id.blank?
        render json: { error: 'Missing device identifier' }, status: :bad_request
        return nil
      end
      device_id
    end

    def device_auth_token
      ENV['DEVICE_AUTH_TOKEN'].presence || read_token_file
    end

    def max_upload_bytes
      (ENV['MAX_UPLOAD_BYTES'].presence || 10.megabytes).to_i
    end

    def reject_oversize!(byte_size, context)
      return true if byte_size.to_i <= max_upload_bytes

      Rails.logger.warn("[API::BaseController] Payload too large for #{context}: #{byte_size} bytes")
      render json: { error: "Payload too large for #{context}", limit_bytes: max_upload_bytes }, status: :payload_too_large
      false
    end

    def read_token_file
      token_path = Rails.root.join('config/device_secret.token')
      return unless File.exist?(token_path)

      File.read(token_path).strip
    rescue StandardError => e
      Rails.logger.error("[API::BaseController] Failed reading token file: #{e.message}")
      nil
    end

    def secure_compare(provided, expected)
      return false if provided.blank? || expected.blank?
      return false unless provided.bytesize == expected.bytesize

      ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    rescue StandardError
      false
    end
  end
end
