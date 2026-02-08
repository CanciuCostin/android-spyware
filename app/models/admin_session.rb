# frozen_string_literal: true

class AdminSession < ApplicationRecord
  belongs_to :admin_user

  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :last_activity_at, presence: true

  scope :active, -> { where(active: true).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def touch_activity!
    update!(last_activity_at: Time.current)
  end

  def deactivate!
    update!(active: false)
  end
end
