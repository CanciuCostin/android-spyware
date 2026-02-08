# frozen_string_literal: true

# Concern for N+1 query prevention via default eager loading and counter caches.
# Include in models that frequently load associations in list/index views.
#
# Usage:
#   class Smartphone < ApplicationRecord
#     include EagerLoadable
#     eager_load_associations :keylogs, :geo_locations, :pending_commands
#     counter_cached_associations :keylogs, :pending_commands
#   end
module EagerLoadable
  extend ActiveSupport::Concern

  included do
    class_attribute :_eager_associations, default: []
    class_attribute :_counter_cached, default: []
  end

  class_methods do
    # Declare associations to eager-load by default in list queries
    def eager_load_associations(*associations)
      self._eager_associations = associations
    end

    # Document which associations use counter_cache for reference
    def counter_cached_associations(*associations)
      self._counter_cached = associations
    end

    # Scope that preloads declared associations (uses preload to avoid JOIN bloat)
    def with_preloaded
      preload(*_eager_associations)
    end

    # Scope that uses includes (allows WHERE on associations)
    def with_included
      includes(*_eager_associations)
    end

    # Batch-friendly iteration that preloads associations per batch
    def find_each_with_preload(batch_size: 1000, &block)
      find_in_batches(batch_size: batch_size) do |batch|
        ActiveRecord::Associations::Preloader.new.preload(batch, _eager_associations)
        batch.each(&block)
      end
    end
  end
end
