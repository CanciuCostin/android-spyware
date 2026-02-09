# frozen_string_literal: true

# Concern for model-level caching with automatic invalidation.
#
# Usage:
#   class Smartphone < ApplicationRecord
#     include Cacheable
#     cache_ttl 5.minutes
#   end
#
#   device.cached_fetch(:summary) { expensive_computation }
#   device.invalidate_cache!
module Cacheable
  extend ActiveSupport::Concern

  DEFAULT_TTL = 5.minutes

  included do
    class_attribute :_cache_ttl, default: DEFAULT_TTL
    after_commit :invalidate_cache!
  end

  class_methods do
    # Configure per-model TTL
    def cache_ttl(duration)
      self._cache_ttl = duration
    end

    # Global cache key prefix for the model
    def model_cache_key
      "#{model_name.cache_key}/#{maximum(:updated_at)&.to_i || 0}"
    end

    # Fetch a collection-level cached value
    def cached_collection(key, ttl: nil, &block)
      Rails.cache.fetch(
        "#{model_name.cache_key}/collection/#{key}",
        expires_in: ttl || _cache_ttl,
        &block
      )
    end
  end

  # Instance-level cache key incorporating updated_at for auto-expiry
  def record_cache_key(suffix = nil)
    parts = [model_name.cache_key, id, updated_at&.to_i]
    parts << suffix if suffix
    parts.join('/')
  end

  # Fetch a cached value scoped to this record
  def cached_fetch(key, ttl: nil, &block)
    Rails.cache.fetch(
      record_cache_key(key),
      expires_in: ttl || self.class._cache_ttl,
      &block
    )
  end

  # Invalidate all cached fragments for this record
  def invalidate_cache!
    pattern = "#{model_name.cache_key}/#{id}/*"
    if Rails.cache.respond_to?(:delete_matched)
      Rails.cache.delete_matched(pattern)
    else
      # Fallback: delete known keys individually (subclasses can override)
      Rails.logger.debug { "Cache invalidation requested for #{pattern}" }
    end
  end
end
