class Alert < ApplicationRecord
  belongs_to :alert_rule
  belongs_to :device, class_name: 'ApkInstallation'
  belongs_to :acknowledged_by, class_name: 'AdminUser', optional: true
  has_many :notification_logs, dependent: :destroy
  
  validates :severity, inclusion: { in: %w[low medium high critical] }
  validates :title, presence: true
  
  scope :unacknowledged, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
  scope :critical, -> { where(severity: 'critical') }
  scope :recent, -> { order(triggered_at: :desc) }
  scope :by_severity, -> { order(Arel.sql("CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END")) }
  
  after_create :send_notifications
  
  def acknowledge!(admin_user)
    with_lock do
      raise ActiveRecord::StaleObjectError, "Alert already acknowledged" if acknowledged?

      update!(acknowledged_at: Time.current, acknowledged_by_id: admin_user.id)
    end
  end
  
  def acknowledged?
    acknowledged_at.present?
  end
  
  private
  
  def send_notifications
    AlertNotificationJob.perform_later(id)
  end
end
