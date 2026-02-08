# frozen_string_literal: true

class KeylogAnalyticsService < ApplicationService
  attr_reader :device, :start_date, :end_date

  def initialize(device, start_date: 30.days.ago, end_date: Time.current)
    @device = device
    @start_date = start_date
    @end_date = end_date
  end

  def call
    {
      summary: summary_stats,
      app_usage: app_usage_distribution,
      activity_timeline: activity_timeline,
      hourly_heatmap: hourly_heatmap,
      peak_hours: peak_activity_hours,
      word_count: word_count_estimate,
      sessions: session_summary
    }
  end

  # Aggregated summary statistics
  def summary_stats
    logs = scoped_keylogs
    {
      total_keystrokes: logs.count,
      unique_apps: logs.distinct.count(:app_package),
      active_days: logs.select("DATE(created_at)").distinct.count,
      avg_keystrokes_per_day: avg_per_day(logs),
      date_range: { start: start_date.iso8601, end: end_date.iso8601 }
    }
  end

  # Per-app keystroke distribution
  def app_usage_distribution
    scoped_keylogs
      .group(:app_package)
      .count
      .sort_by { |_, v| -v }
      .map { |app, count| { app_package: app, keystroke_count: count, percentage: 0 } }
      .tap do |results|
        total = results.sum { |r| r[:keystroke_count] }
        results.each { |r| r[:percentage] = total.positive? ? (r[:keystroke_count].to_f / total * 100).round(1) : 0 }
      end
  end

  # Hourly/daily activity timeline
  def activity_timeline(granularity: :hourly)
    case granularity
    when :hourly
      scoped_keylogs
        .group("DATE(created_at)", "EXTRACT(HOUR FROM created_at)")
        .count
        .map { |(date, hour), count| { date: date.to_s, hour: hour.to_i, count: count } }
    when :daily
      scoped_keylogs
        .group("DATE(created_at)")
        .count
        .sort_by { |date, _| date }
        .map { |date, count| { date: date.to_s, count: count } }
    end
  end

  # 24-hour heatmap (hour × day_of_week matrix)
  def hourly_heatmap
    data = scoped_keylogs
      .group("EXTRACT(DOW FROM created_at)", "EXTRACT(HOUR FROM created_at)")
      .count

    (0..6).map do |dow|
      {
        day: %w[Sun Mon Tue Wed Thu Fri Sat][dow],
        hours: (0..23).map { |h| data[[dow.to_f, h.to_f]] || data[[dow, h]] || 0 }
      }
    end
  end

  # Top 5 peak activity hours
  def peak_activity_hours
    scoped_keylogs
      .group("EXTRACT(HOUR FROM created_at)")
      .count
      .sort_by { |_, v| -v }
      .first(5)
      .map { |hour, count| { hour: hour.to_i, count: count } }
  end

  # Estimated word count from TEXT_CHANGED events
  def word_count_estimate
    text_logs = scoped_keylogs.where(event_type: 'TEXT_CHANGED')
    total_chars = text_logs.sum("LENGTH(keystroke)")
    {
      total_characters: total_chars,
      estimated_words: (total_chars / 5.0).round, # avg word length ~5 chars
      text_events: text_logs.count
    }
  end

  # Detect typing sessions (gaps > 5 min = new session)
  def session_summary
    logs = scoped_keylogs.order(:created_at).pluck(:created_at)
    return { total_sessions: 0, avg_session_minutes: 0 } if logs.empty?

    sessions = []
    session_start = logs.first
    prev = logs.first

    logs.each do |ts|
      if (ts - prev) > 5.minutes
        sessions << { start: session_start, end: prev, duration_minutes: ((prev - session_start) / 60.0).round(1) }
        session_start = ts
      end
      prev = ts
    end
    sessions << { start: session_start, end: prev, duration_minutes: ((prev - session_start) / 60.0).round(1) }

    avg_duration = sessions.any? ? (sessions.sum { |s| s[:duration_minutes] } / sessions.size).round(1) : 0

    {
      total_sessions: sessions.size,
      avg_session_minutes: avg_duration,
      longest_session_minutes: sessions.map { |s| s[:duration_minutes] }.max || 0
    }
  end

  private

  def scoped_keylogs
    Keylog.where(smartphone: device)
          .where(created_at: start_date..end_date)
  end

  def avg_per_day(logs)
    days = ((end_date - start_date) / 1.day).ceil
    days.positive? ? (logs.count.to_f / days).round(1) : 0
  end
end
