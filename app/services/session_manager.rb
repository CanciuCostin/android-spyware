# frozen_string_literal: true

# Manages admin user sessions with timeout, concurrency limits, and activity tracking.
class SessionManager
  DEFAULT_TIMEOUT_MINUTES = 30
  MAX_CONCURRENT_SESSIONS = 3

  class << self
    def timeout_minutes
      (ENV['SESSION_TIMEOUT_MINUTES'].presence || DEFAULT_TIMEOUT_MINUTES).to_i
    end

    def max_sessions
      (ENV['MAX_CONCURRENT_SESSIONS'].presence || MAX_CONCURRENT_SESSIONS).to_i
    end

    # Create a new session, enforcing the concurrency limit
    def create_session(admin_user, request)
      enforce_session_limit(admin_user)

      token = SecureRandom.urlsafe_base64(32)
      session = AdminSession.create!(
        admin_user: admin_user,
        session_token: token,
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(255),
        last_activity_at: Time.current,
        expires_at: timeout_minutes.minutes.from_now
      )

      { session_token: token, expires_at: session.expires_at }
    end

    # Validate and refresh an existing session
    def validate_session(token)
      return nil if token.blank?

      session = AdminSession.find_by(session_token: token, active: true)
      return nil unless session
      return expire_session(session) if session.expired?

      # Check inactivity timeout
      if session.last_activity_at < timeout_minutes.minutes.ago
        expire_session(session)
        return nil
      end

      session.touch_activity!
      session.update!(expires_at: timeout_minutes.minutes.from_now)
      session
    end

    # Force logout from a specific session
    def destroy_session(token)
      session = AdminSession.find_by(session_token: token)
      session&.deactivate!
    end

    # Force logout from all sessions for an admin user
    def destroy_all_sessions(admin_user)
      admin_user.admin_sessions.active.update_all(active: false)
    end

    # List active sessions for an admin user
    def active_sessions(admin_user)
      admin_user.admin_sessions.active.order(last_activity_at: :desc).map do |s|
        {
          id: s.id,
          ip_address: s.ip_address,
          user_agent: s.user_agent,
          last_activity_at: s.last_activity_at,
          created_at: s.created_at
        }
      end
    end

    # Clean up expired sessions (run periodically)
    def cleanup_expired
      AdminSession.expired.update_all(active: false)
    end

    private

    def enforce_session_limit(admin_user)
      active = admin_user.admin_sessions.active.order(last_activity_at: :asc)
      excess = active.count - max_sessions + 1
      return unless excess > 0

      # Deactivate oldest sessions to make room
      active.limit(excess).update_all(active: false)
    end

    def expire_session(session)
      session.deactivate!
      nil
    end
  end
end
