# frozen_string_literal: true

# Manages user preference operations including validation and defaults.
#
# Usage:
#   PreferenceService.get_for(admin_user)
#   PreferenceService.update_for(admin_user, { 'dashboard' => { 'layout' => 'list' } })
#   PreferenceService.reset_for(admin_user)
class PreferenceService
  VALID_LAYOUTS = %w[grid list].freeze
  VALID_FONT_SIZES = %w[small medium large].freeze
  VALID_SORT_DIRECTIONS = %w[asc desc].freeze
  VALID_THEME_MODES = %w[dark light].freeze
  MAX_SAVED_VIEWS = 20
  MAX_REFRESH_INTERVAL = 300
  MIN_REFRESH_INTERVAL = 5

  class << self
    def get_for(admin_user)
      pref = find_or_create(admin_user)
      pref.merged_preferences
    end

    def update_for(admin_user, new_preferences)
      pref = find_or_create(admin_user)
      validated = validate_preferences(new_preferences)
      merged = deep_merge(pref.preferences || {}, validated)
      pref.update!(preferences: merged)
      pref.merged_preferences
    end

    def reset_for(admin_user)
      pref = find_or_create(admin_user)
      pref.reset!
      pref.merged_preferences
    end

    def get_value(admin_user, key_path)
      pref = find_or_create(admin_user)
      pref.get(key_path)
    end

    def set_value(admin_user, key_path, value)
      pref = find_or_create(admin_user)
      pref.set(key_path, value)
      pref.merged_preferences
    end

    def defaults
      UserPreference::DEFAULTS
    end

    private

    def find_or_create(admin_user)
      UserPreference.find_or_create_by!(admin_user: admin_user)
    rescue ActiveRecord::RecordNotUnique
      UserPreference.find_by!(admin_user: admin_user)
    end

    def validate_preferences(prefs)
      return {} unless prefs.is_a?(Hash)

      validated = {}

      if prefs['dashboard'].is_a?(Hash)
        dash = prefs['dashboard']
        validated['dashboard'] = {}
        validated['dashboard']['layout'] = dash['layout'] if VALID_LAYOUTS.include?(dash['layout'])
        validated['dashboard']['columns'] = dash['columns'] if dash['columns'].is_a?(Array)
        validated['dashboard']['auto_refresh'] = !!dash['auto_refresh'] if dash.key?('auto_refresh')

        if dash['refresh_interval'].is_a?(Numeric)
          validated['dashboard']['refresh_interval'] = dash['refresh_interval'].clamp(MIN_REFRESH_INTERVAL, MAX_REFRESH_INTERVAL)
        end
      end

      if prefs['notifications'].is_a?(Hash)
        notif = prefs['notifications']
        validated['notifications'] = {}
        %w[email in_app webhook notify_on_connect notify_on_disconnect notify_on_error].each do |key|
          validated['notifications'][key] = !!notif[key] if notif.key?(key)
        end
        if notif['webhook_url'].is_a?(String)
          validated['notifications']['webhook_url'] = notif['webhook_url'] if notif['webhook_url'] =~ /\Ahttps?:\/\//
        end
      end

      if prefs['theme'].is_a?(Hash)
        theme = prefs['theme']
        validated['theme'] = {}
        validated['theme']['mode'] = theme['mode'] if VALID_THEME_MODES.include?(theme['mode'])
        validated['theme']['font_size'] = theme['font_size'] if VALID_FONT_SIZES.include?(theme['font_size'])
        validated['theme']['accent_color'] = theme['accent_color'] if theme['accent_color']&.match?(/\A#[0-9a-fA-F]{6}\z/)
        validated['theme']['compact_mode'] = !!theme['compact_mode'] if theme.key?('compact_mode')
      end

      if prefs['filters'].is_a?(Hash)
        filters = prefs['filters']
        validated['filters'] = {}
        if filters['default_date_range'].is_a?(Numeric) && filters['default_date_range'].between?(1, 365)
          validated['filters']['default_date_range'] = filters['default_date_range'].to_i
        end
        if filters['saved_views'].is_a?(Array)
          validated['filters']['saved_views'] = filters['saved_views'].first(MAX_SAVED_VIEWS)
        end
      end

      if prefs['data'].is_a?(Hash)
        data = prefs['data']
        validated['data'] = {}
        if data['records_per_page'].is_a?(Numeric) && data['records_per_page'].between?(10, 100)
          validated['data']['records_per_page'] = data['records_per_page'].to_i
        end
        validated['data']['default_sort'] = data['default_sort'] if data['default_sort'].is_a?(String)
        validated['data']['default_sort_direction'] = data['default_sort_direction'] if VALID_SORT_DIRECTIONS.include?(data['default_sort_direction'])
        validated['data']['auto_refresh_data'] = !!data['auto_refresh_data'] if data.key?('auto_refresh_data')
      end

      validated.reject { |_, v| v.is_a?(Hash) && v.empty? }
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
end
