# frozen_string_literal: true

class ScreenMirroringService < ApplicationService
  MAX_SESSION_DURATION = 30.minutes
  DEFAULT_FPS = 15
  DEFAULT_QUALITY = 70
  MIN_FPS = 1
  MAX_FPS = 30
  MIN_QUALITY = 10
  MAX_QUALITY = 100

  def initialize(device, options = {})
    @device = device
    @admin_user = options[:admin_user]
    @fps = clamp(options.fetch(:fps, DEFAULT_FPS).to_i, MIN_FPS, MAX_FPS)
    @quality = clamp(options.fetch(:quality, DEFAULT_QUALITY).to_i, MIN_QUALITY, MAX_QUALITY)
  end

  def start_session
    return Result.failure('Device not found') unless @device
    return Result.failure('Consent not granted for device_monitoring') unless consent_granted?

    existing = active_session
    return Result.failure('Session already active') if existing

    session = build_session
    cache_session(session)

    broadcast_start_command(session)
    schedule_timeout(session[:session_id])
    log_session_event('screen_mirror_started', session)

    Result.success(session)
  rescue => e
    Rails.logger.error("[ScreenMirroringService] start_session failed: #{e.message}")
    Result.failure(e.message)
  end

  def stop_session
    session = active_session
    return Result.failure('No active session') unless session

    session[:status] = 'stopped'
    session[:ended_at] = Time.current.iso8601
    session[:duration_seconds] = compute_duration(session)

    broadcast_stop_command
    remove_session
    log_session_event('screen_mirror_stopped', session)

    Result.success(session)
  rescue => e
    Rails.logger.error("[ScreenMirroringService] stop_session failed: #{e.message}")
    Result.failure(e.message)
  end

  def session_status
    session = active_session
    return Result.success({ status: 'inactive', device_id: device_id }) unless session

    session[:elapsed_seconds] = compute_duration(session)
    session[:remaining_seconds] = [MAX_SESSION_DURATION.to_i - session[:elapsed_seconds], 0].max
    Result.success(session)
  end

  def update_settings(fps: nil, quality: nil)
    session = active_session
    return Result.failure('No active session') unless session

    session[:fps] = clamp(fps.to_i, MIN_FPS, MAX_FPS) if fps
    session[:quality] = clamp(quality.to_i, MIN_QUALITY, MAX_QUALITY) if quality
    cache_session(session)

    ActionCable.server.broadcast(
      "screen_mirror_#{device_id}",
      { type: 'settings_update', fps: session[:fps], quality: session[:quality] }
    )

    Result.success(session)
  end

  def handle_timeout(session_id)
    session = active_session
    return unless session && session[:session_id] == session_id

    session[:status] = 'timed_out'
    session[:ended_at] = Time.current.iso8601
    session[:duration_seconds] = MAX_SESSION_DURATION.to_i

    broadcast_stop_command
    remove_session
    log_session_event('screen_mirror_timed_out', session)

    ActionCable.server.broadcast(
      "screen_mirror_#{device_id}_admin",
      { type: 'session_timeout', session_id: session_id }
    )
  end

  private

  def device_id
    @device.respond_to?(:device_id) ? @device.device_id : @device.id.to_s
  end

  def consent_granted?
    ConsentService.new(@device).check_consent('device_monitoring')
  end

  def active_session
    data = Rails.cache.read(session_cache_key)
    return nil unless data
    data.is_a?(Hash) ? data : nil
  end

  def build_session
    {
      session_id: SecureRandom.uuid,
      device_id: device_id,
      started_by: @admin_user,
      started_at: Time.current.iso8601,
      status: 'active',
      fps: @fps,
      quality: @quality,
      max_duration_seconds: MAX_SESSION_DURATION.to_i
    }
  end

  def cache_session(session)
    Rails.cache.write(session_cache_key, session, expires_in: MAX_SESSION_DURATION + 1.minute)
  end

  def remove_session
    Rails.cache.delete(session_cache_key)
  end

  def session_cache_key
    "screen_mirror:session:#{device_id}"
  end

  def broadcast_start_command(session)
    ActionCable.server.broadcast(
      "screen_mirror_#{device_id}",
      {
        type: 'start_mirror',
        session_id: session[:session_id],
        fps: session[:fps],
        quality: session[:quality]
      }
    )
  end

  def broadcast_stop_command
    ActionCable.server.broadcast(
      "screen_mirror_#{device_id}",
      { type: 'stop_mirror' }
    )
  end

  def schedule_timeout(session_id)
    ScreenMirrorTimeoutJob.set(wait: MAX_SESSION_DURATION).perform_later(device_id, session_id) if defined?(ScreenMirrorTimeoutJob)
  rescue => e
    Rails.logger.warn("[ScreenMirroringService] Could not schedule timeout job: #{e.message}")
  end

  def compute_duration(session)
    started = Time.parse(session[:started_at]) rescue Time.current
    (Time.current - started).to_i
  end

  def log_session_event(action, session)
    AuditService.log(
      action: action,
      auditable: @device,
      metadata: session.slice(:session_id, :started_by, :fps, :quality, :duration_seconds)
    )
  rescue => e
    Rails.logger.error("[ScreenMirroringService] Audit log failed: #{e.message}")
  end

  def clamp(value, min, max)
    [[value, min].max, max].min
  end
end
