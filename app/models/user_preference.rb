# frozen_string_literal: true

class UserPreference < ApplicationRecord
  belongs_to :admin_user

  validates :admin_user_id, uniqueness: true

  DEFAULTS = {
    'dashboard' => {
      'layout' => 'grid',
      'columns' => %w[status name device_id os last_activity],
      'auto_refresh' => true,
      'refresh_interval' => 30
    },
    'notifications' => {
      'email' => true,
      'in_app' => true,
      'webhook' => false,
      'webhook_url' => nil,
      'notify_on_connect' => true,
      'notify_on_disconnect' => true,
      'notify_on_error' => true
    },
    'theme' => {
      'mode' => 'dark',
      'font_size' => 'medium',
      'accent_color' => '#00d4ff',
      'compact_mode' => false
    },
    'filters' => {
      'default_date_range' => 7,
      'saved_views' => []
    },
    'data' => {
      'records_per_page' => 25,
      'default_sort' => 'created_at',
      'default_sort_direction' => 'desc',
      'auto_refresh_data' => false
    }
  }.freeze

  after_initialize :set_defaults

  def get(key_path)
    keys = key_path.to_s.split('.')
    merged_preferences.dig(*keys)
  end

  def set(key_path, value)
    keys = key_path.to_s.split('.')
    current = preferences || {}
    nested = current

    keys[0..-2].each do |key|
      nested[key] ||= {}
      nested = nested[key]
    end

    nested[keys.last] = value
    update!(preferences: current)
  end

  def merged_preferences
    deep_merge(DEFAULTS, preferences || {})
  end

  def reset!
    update!(preferences: {})
  end

  private

  def set_defaults
    self.preferences ||= {}
  end

  def deep_merge(base, override)
    base.each_with_object({}) do |(key, base_value), result|
      if override.key?(key)
        if base_value.is_a?(Hash) && override[key].is_a?(Hash)
          result[key] = deep_merge(base_value, override[key])
        else
          result[key] = override[key]
        end
      else
        result[key] = base_value
      end
    end.merge(override.reject { |k, _| base.key?(k) })
  end
end
