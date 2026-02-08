# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :admin_user, optional: true

  validates :key_digest, presence: true, uniqueness: true
  validates :key_prefix, presence: true
  validates :name, presence: true
  validates :scope, inclusion: { in: %w[read_only full_access] }

  scope :active, -> { where(revoked: false).where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :revoked, -> { where(revoked: true) }
  scope :for_device, ->(device_id) { where(device_id: device_id) }

  def revoke!
    update!(revoked: true, revoked_at: Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !revoked? && !expired?
  end

  def track_usage!
    increment!(:usage_count)
    update_column(:last_used_at, Time.current)
  end

  def read_only?
    scope == 'read_only'
  end

  def full_access?
    scope == 'full_access'
  end
end
