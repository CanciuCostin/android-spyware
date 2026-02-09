# frozen_string_literal: true

class ScheduledCommand < ApplicationRecord
  belongs_to :smartphone
  has_many :executions, class_name: 'ScheduledCommandExecution', dependent: :destroy

  enum schedule_type: { once: 0, recurring: 1 }

  validates :command, presence: true,
            inclusion: { in: CommandSender::ALLOWED_COMMANDS, message: '%{value} is not a valid command' }
  validates :schedule_type, presence: true
  validates :cron_expression, presence: true, if: :recurring?
  validates :next_run_at, presence: true
  validates :run_count, numericality: { greater_than_or_equal_to: 0 }
  validates :max_runs, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :due, -> { active.where('next_run_at <= ?', Time.current) }
  scope :once_type, -> { where(schedule_type: :once) }
  scope :recurring_type, -> { where(schedule_type: :recurring) }
  scope :for_device, ->(smartphone_id) { where(smartphone_id: smartphone_id) }
  scope :by_next_run, -> { order(next_run_at: :asc) }

  before_validation :set_defaults, on: :create

  def due?
    active? && next_run_at.present? && next_run_at <= Time.current
  end

  def max_runs_reached?
    max_runs.present? && run_count >= max_runs
  end

  def record_execution!(status:, result: nil, duration_ms: nil, pending_command: nil)
    transaction do
      self.run_count += 1
      self.last_run_at = Time.current
      self.last_result = result
      self.last_status = status

      if once?
        self.active = false
      elsif recurring?
        if max_runs_reached?
          self.active = false
        else
          self.next_run_at = CommandSchedulerService.next_run_time(cron_expression)
        end
      end

      save!

      executions.create!(
        status: status,
        result: result,
        executed_at: Time.current,
        duration_ms: duration_ms,
        pending_command: pending_command
      )
    end
  end

  private

  def set_defaults
    self.run_count ||= 0
    self.active = true if active.nil?
  end
end
