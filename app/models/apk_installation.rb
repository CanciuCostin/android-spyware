class ApkInstallation < ApplicationRecord
  belongs_to :apk_payload
  
  # Validations
  validates :target_ip, presence: true, format: {
    with: /\A[a-zA-Z0-9_.:-]+\z/,
    message: "must contain only letters, numbers, dots, colons, underscores, or hyphens"
  }
  validates :status, inclusion: { in: %w[pending installed failed], allow_blank: true }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  
  private
  
  def set_default_status
    self.status ||= 'pending'
  end
end
