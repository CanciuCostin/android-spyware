# frozen_string_literal: true

class AdminTwoFactor < ApplicationRecord
  belongs_to :admin_user

  validates :otp_secret, presence: true
  validates :admin_user_id, uniqueness: true

  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 15.minutes

  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def record_failed_attempt!
    increment!(:failed_attempts)
    if failed_attempts >= MAX_FAILED_ATTEMPTS
      update!(locked_until: Time.current + LOCKOUT_DURATION)
    end
  end

  def reset_failed_attempts!
    update!(failed_attempts: 0, locked_until: nil)
  end

  def consume_backup_code!(code)
    return false unless backup_codes.is_a?(Array)

    idx = backup_codes.index(code)
    return false unless idx

    codes = backup_codes.dup
    codes.delete_at(idx)
    update!(backup_codes: codes, last_used_at: Time.current)
    true
  end
end
