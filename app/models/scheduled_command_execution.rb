# frozen_string_literal: true

class ScheduledCommandExecution < ApplicationRecord
  belongs_to :scheduled_command
  belongs_to :pending_command, optional: true

  validates :status, presence: true, inclusion: { in: %w[queued success failed timeout] }
  validates :executed_at, presence: true

  scope :recent, -> { order(executed_at: :desc) }
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: 'failed') }
end
