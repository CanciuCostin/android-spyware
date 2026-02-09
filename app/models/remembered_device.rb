# frozen_string_literal: true

class RememberedDevice < ApplicationRecord
  belongs_to :admin_user

  validates :device_fingerprint, presence: true
  validates :expires_at, presence: true

  scope :valid, -> { where('expires_at > ?', Time.current) }

  def expired?
    expires_at <= Time.current
  end
end
