# frozen_string_literal: true

class QueuedCommand < ApplicationRecord
  belongs_to :smartphone

  validates :command, presence: true
  validates :priority, numericality: { in: 1..10 }
  validates :status, inclusion: { in: %w[pending sending sent failed expired] }
  validates :expires_at, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :expired, -> { where(status: 'pending').where('expires_at < ?', Time.current) }
  scope :by_priority, -> { order(priority: :asc, created_at: :asc) }
end
