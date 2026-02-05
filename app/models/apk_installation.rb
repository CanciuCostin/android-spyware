class ApkInstallation < ApplicationRecord
  belongs_to :apk_payload
  
  # Validations
  validates :target_ip, presence: true, format: { 
    with: /\A(?:(?:\d{1,3}\.){3}\d{1,3}|[a-fA-F0-9:]+)\z/, 
    message: "must be valid IPv4 or IPv6 address" 
  }
  validates :status, inclusion: { in: %w[pending installed failed], allow_blank: true }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  
  private
  
  def set_default_status
    self.status ||= 'pending'
  end
end
