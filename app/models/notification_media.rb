class NotificationMedia < ApplicationRecord
  belongs_to :device_notification
  
  validates :media_type, presence: true, inclusion: { in: %w[icon large_icon big_picture] }
  
  def base64_data
    return nil unless data
    Base64.strict_encode64(data)
  end
  
  def data_uri
    return nil unless data && mime_type
    "data:#{mime_type};base64,#{base64_data}"
  end
end
