# frozen_string_literal: true

# Concern for adding HTTP-level caching to controllers.
# Provides ETag / Last-Modified helpers, conditional GET support,
# and fragment caching wrappers.
#
# Usage:
#   class Api::DevicesController < ApplicationController
#     include CacheableActions
#
#     def show
#       @device = Smartphone.find(params[:id])
#       return if fresh_by(etag: @device, last_modified: @device.updated_at)
#       render json: @device
#     end
#   end
module CacheableActions
  extend ActiveSupport::Concern

  private

  # Returns true (and sends 304) when the client's cache is still valid.
  # Wraps Rails' stale? with sensible defaults.
  def fresh_by(etag: nil, last_modified: nil, public_cache: false)
    return false unless stale?(
      etag: etag,
      last_modified: last_modified,
      public: public_cache,
      template: false
    )
    false
  rescue StandardError
    false
  end

  # Set Cache-Control headers for API responses.
  #   cache_for 30.seconds
  #   cache_for 5.minutes, public: true
  def cache_for(duration, public_cache: false)
    if public_cache
      expires_in duration, public: true
    else
      expires_in duration, public: false, must_revalidate: true
    end
  end

  # Prevent caching entirely (already the Rails default for most actions).
  def no_cache!
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Thu, 01 Jan 1970 00:00:00 GMT'
  end

  # Fragment cache helper — wraps Rails.cache.fetch with a controller-aware key.
  #   cached_fragment('device_list', expires_in: 1.minute) { Device.all.to_json }
  def cached_fragment(key, expires_in: 5.minutes, &block)
    cache_key = "fragment:#{controller_name}:#{action_name}:#{key}"
    CacheService.fetch(cache_key, expires_in: expires_in, &block)
  end

  # Conditional GET for collection endpoints.
  # Returns true if the collection hasn't changed since the client's last request.
  def fresh_collection?(scope)
    latest = scope.maximum(:updated_at)
    count = scope.count
    etag_value = "#{scope.model_name.cache_key}/#{count}-#{latest&.to_i}"

    return false unless stale?(etag: etag_value, last_modified: latest, template: false)
    false
  rescue StandardError
    false
  end
end
