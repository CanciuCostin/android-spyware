# frozen_string_literal: true

class TrackedError < ApplicationRecord
  STATUSES = %w[open resolved ignored].freeze
  AUTO_RESOLVE_DAYS = 7

  validates :fingerprint, presence: true, uniqueness: true
  validates :error_class, presence: true
  validates :message, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :count, numericality: { greater_than_or_equal_to: 0 }

  scope :open_errors, -> { where(status: 'open') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :ignored, -> { where(status: 'ignored') }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :most_frequent, -> { order(count: :desc) }
  scope :stale, -> { open_errors.where('last_seen_at < ?', AUTO_RESOLVE_DAYS.days.ago) }

  def resolve!
    update!(status: 'resolved', resolved_at: Time.current)
  end

  def ignore!
    update!(status: 'ignored')
  end

  def reopen!
    update!(status: 'open', resolved_at: nil)
  end

  def affected_device_count
    (device_ids || []).uniq.size
  end

  def add_device(device_id)
    return if device_id.blank?

    current = device_ids || []
    unless current.include?(device_id)
      current << device_id
      update!(device_ids: current)
    end
  end

  def increment_occurrence!(new_backtrace: nil, device_id: nil)
    attrs = {
      count: count + 1,
      last_seen_at: Time.current
    }
    attrs[:backtrace] = new_backtrace if new_backtrace.present?
    attrs[:status] = 'open' if status == 'resolved'

    if device_id.present?
      current = device_ids || []
      attrs[:device_ids] = (current + [device_id]).uniq
    end

    update!(attrs)
  end

  def self.auto_resolve_stale!
    stale.update_all(status: 'resolved', resolved_at: Time.current, updated_at: Time.current)
  end
end
