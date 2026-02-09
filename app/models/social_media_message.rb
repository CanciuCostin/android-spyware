class SocialMediaMessage < ApplicationRecord
  belongs_to :smartphone

  validates :body, :app_name, :sender, :sent_at, presence: true

  scope :whatsapp, -> { where(app_name: 'WhatsApp') }
  scope :viber, -> { where(app_name: 'Viber') }
  scope :telegram, -> { where(app_name: 'Telegram') }
  scope :facebook, -> { where(app_name: 'Facebook') }
end
