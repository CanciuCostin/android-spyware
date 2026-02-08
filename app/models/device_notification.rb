class DeviceNotification < ApplicationRecord
  has_many :notification_media, dependent: :destroy
  
  validates :device_id, presence: true
  validates :package_name, presence: true
  
  scope :by_device, ->(device_id) { where(device_id: device_id) }
  scope :recent, -> { order(post_time: :desc) }
  scope :by_app, ->(package_name) { where(package_name: package_name) }
  scope :messaging_apps, -> { where(package_name: MESSAGING_APPS) }
  
  MESSAGING_APPS = %w[
    com.whatsapp
    com.facebook.orca
    org.telegram.messenger
    com.viber.voip
    com.instagram.android
    com.snapchat.android
    com.twitter.android
    com.discord
    com.skype.raider
    com.tencent.mm
    com.google.android.apps.messaging
    com.samsung.android.messaging
  ].freeze
  
  def messaging_app?
    MESSAGING_APPS.include?(package_name)
  end
  
  def display_time
    return nil unless post_time
    Time.at(post_time / 1000) rescue nil
  end
  
  def app_icon
    notification_media.find_by(media_type: 'icon')
  end
  
  def large_icon
    notification_media.find_by(media_type: 'large_icon')
  end
  
  def big_picture
    notification_media.find_by(media_type: 'big_picture')
  end
end
