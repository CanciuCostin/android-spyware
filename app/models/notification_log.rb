class NotificationLog < ApplicationRecord
  belongs_to :alert
  belongs_to :notification_channel

  validates :alert, :notification_channel, presence: true
  validates :status, inclusion: { in: %w[sent failed pending] }
  
  scope :sent, -> { where(status: 'sent') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :recent, -> { order(created_at: :desc) }
end
