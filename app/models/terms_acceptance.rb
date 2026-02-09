class TermsAcceptance < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation'
  
  validates :terms_version, presence: true
  
  scope :accepted, -> { where(accepted: true) }
  scope :for_version, ->(version) { where(terms_version: version) }
  
  def accept!(ip_address:, user_agent:)
    update!(
      accepted: true,
      accepted_at: Time.current,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end
end
