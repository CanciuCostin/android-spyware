# frozen_string_literal: true

module Api
  class KeylogAnalyticsController < Api::BaseController
    before_action :set_device
    before_action :verify_consent

    # GET /api/devices/:id/keylog_analytics
    def show
      service = KeylogAnalyticsService.new(@device, start_date: parsed_start, end_date: parsed_end)
      analytics = service.call

      render json: {
        device_id: @device.device_id,
        consent_status: consent_status,
        analytics: analytics
      }
    end

    # GET /api/devices/:id/keylog_analytics/app_usage
    def app_usage
      service = KeylogAnalyticsService.new(@device, start_date: parsed_start, end_date: parsed_end)

      render json: {
        device_id: @device.device_id,
        app_usage: service.app_usage_distribution
      }
    end

    # GET /api/devices/:id/keylog_analytics/activity_timeline
    def activity_timeline
      granularity = %w[hourly daily].include?(params[:granularity]) ? params[:granularity].to_sym : :hourly
      service = KeylogAnalyticsService.new(@device, start_date: parsed_start, end_date: parsed_end)

      render json: {
        device_id: @device.device_id,
        granularity: granularity,
        timeline: service.activity_timeline(granularity: granularity)
      }
    end

    # GET /api/devices/:id/keylog_analytics/export
    def export
      format = %w[csv json].include?(params[:export_format]) ? params[:export_format] : 'json'
      service = KeylogExportService.new(@device, format: format, start_date: parsed_start, end_date: parsed_end)
      data = service.call

      if format == 'csv'
        send_data data,
                  filename: "keylog_analytics_#{@device.device_id}_#{Time.current.to_i}.csv",
                  type: 'text/csv'
      else
        render json: JSON.parse(data)
      end
    end

    private

    def set_device
      @device = Smartphone.find_by(id: params[:id]) || Smartphone.find_by(device_id: params[:id])
      render json: { error: 'Device not found' }, status: :not_found unless @device
    end

    def verify_consent
      return unless @device

      consent = DeviceConsent.find_by(device_id: @device.id, consent_type: 'data_collection')
      unless consent&.active?
        render json: {
          error: 'Consent required: data_collection',
          code: 'CONSENT_REQUIRED',
          device_id: @device.device_id
        }, status: :forbidden
      end
    end

    def consent_status
      consent = DeviceConsent.find_by(device_id: @device.id, consent_type: 'data_collection')
      consent&.active? ? 'granted' : 'not_granted'
    rescue
      'unknown'
    end

    def parsed_start
      params[:start_date].present? ? Time.parse(params[:start_date]) : 30.days.ago
    rescue ArgumentError
      30.days.ago
    end

    def parsed_end
      params[:end_date].present? ? Time.parse(params[:end_date]) : Time.current
    rescue ArgumentError
      Time.current
    end
  end
end
