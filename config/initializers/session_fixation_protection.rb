# frozen_string_literal: true

# Session fixation protection: regenerate session ID after authentication.
# Devise 4.9+ handles this internally via Warden's after_set_user hook,
# but we add an explicit callback for defense-in-depth.
Warden::Manager.after_authentication do |user, warden, options|
  # Preserve any data needed across session reset
  old_session = warden.request.session.to_hash
  old_session.delete('session_id')

  warden.request.reset_session

  # Restore non-sensitive session data (e.g. flash, return_to)
  old_session.each do |key, value|
    warden.request.session[key] = value
  end

  Rails.logger.info("[SessionFixation] Session regenerated for user #{user.id}")
end
