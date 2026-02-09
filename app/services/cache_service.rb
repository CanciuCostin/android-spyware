# frozen_string_literal: true

# Centralised caching service for domain-specific data.
# Wraps Rails.cache with predefined TTLs, namespacing, and
# cache-warming / invalidation helpers.
#
# Usage:
#   CacheService.device_status(device_id)
#   CacheService.dashboard_data { expensive_query }
#   CacheService.invalidate_device(device_id)
class CacheService
  # ── TTL constants ──
  DEVICE_STATUS_TTL  = 30.seconds
  DASHBOARD_DATA_TTL = 5.minutes
  STATISTICS_TTL     = 10.minutes

  NAMESPACE = 'eaglespy'

  class << self
    # ── Device Status ──

    def device_status(device_id, &block)
      fetch("device_status:#{device_id}", expires_in: DEVICE_STATUS_TTL, &block)
    end

    def invalidate_device(device_id)
      delete("device_status:#{device_id}")
    end

    # ── Dashboard ──

    def dashboard_data(key = 'main', &block)
      fetch("dashboard:#{key}", expires_in: DASHBOARD_DATA_TTL, &block)
    end

    def invalidate_dashboard(key = nil)
      if key
        delete("dashboard:#{key}")
      else
        delete_matched("dashboard:*")
      end
    end

    # ── Statistics ──

    def statistics(scope, &block)
      fetch("statistics:#{scope}", expires_in: STATISTICS_TTL, &block)
    end

    def invalidate_statistics(scope = nil)
      if scope
        delete("statistics:#{scope}")
      else
        delete_matched("statistics:*")
      end
    end

    # ── Generic helpers ──

    def fetch(key, expires_in: DASHBOARD_DATA_TTL, force: false, &block)
      full_key = namespaced(key)
      Rails.cache.fetch(full_key, expires_in: expires_in, force: force, &block)
    end

    def read(key)
      Rails.cache.read(namespaced(key))
    end

    def write(key, value, expires_in: DASHBOARD_DATA_TTL)
      Rails.cache.write(namespaced(key), value, expires_in: expires_in)
    end

    def delete(key)
      Rails.cache.delete(namespaced(key))
    end

    def delete_matched(pattern)
      Rails.cache.delete_matched(namespaced(pattern))
    rescue NotImplementedError
      # Memory store supports delete_matched; null_store does not
      Rails.logger.debug "[CacheService] delete_matched not supported by current store"
    end

    def exist?(key)
      Rails.cache.exist?(namespaced(key))
    end

    # ── Cache warming ──
    # Call on deploy or process boot to pre-populate hot keys.

    def warm!
      Rails.logger.info "[CacheService] Warming cache…"

      warm_dashboard_data
      warm_device_statuses

      Rails.logger.info "[CacheService] Cache warm complete"
    rescue StandardError => e
      Rails.logger.error "[CacheService] Cache warm failed: #{e.message}"
    end

    # ── Bulk invalidation ──

    def invalidate_all!
      delete_matched("*")
      Rails.logger.info "[CacheService] All caches invalidated"
    end

    private

    def namespaced(key)
      "#{NAMESPACE}:#{key}"
    end

    def warm_dashboard_data
      dashboard_data('main') do
        {
          total_devices: Smartphone.count,
          online_devices: HeartbeatMonitor.get_all_online_devices.size,
          total_keylogs: (Keylog.count rescue 0),
          total_sms: SmsMessage.count,
          total_locations: GeoLocation.count,
          total_photos: Picture.count,
          total_recordings: Recording.count
        }
      end
    rescue StandardError => e
      Rails.logger.warn "[CacheService] Dashboard warm failed: #{e.message}"
    end

    def warm_device_statuses
      Smartphone.find_each do |device|
        device_status(device.id) do
          {
            id: device.id,
            name: device.name,
            online: HeartbeatMonitor.is_online?(device.device_id),
            last_seen: HeartbeatMonitor.get_last_seen(device.device_id)
          }
        end
      end
    rescue StandardError => e
      Rails.logger.warn "[CacheService] Device status warm failed: #{e.message}"
    end
  end
end
