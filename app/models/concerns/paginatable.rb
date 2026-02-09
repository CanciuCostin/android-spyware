# frozen_string_literal: true

# Concern for efficient pagination on large tables.
# Supports cursor-based pagination (fast for large offsets) and
# traditional offset pagination with total-count caching.
#
# Usage:
#   Keylog.cursor_paginate(after: last_id, limit: 50)
#   Keylog.offset_paginate(page: 3, per_page: 25)
module Paginatable
  extend ActiveSupport::Concern

  MAX_PAGE_SIZE  = 100
  DEFAULT_PAGE_SIZE = 25

  class_methods do
    # Cursor-based pagination — efficient for large tables.
    # Returns records with id < after (descending) or id > after (ascending).
    def cursor_paginate(after: nil, before: nil, limit: DEFAULT_PAGE_SIZE, order: :desc)
      limit = [limit.to_i, MAX_PAGE_SIZE].min
      limit = DEFAULT_PAGE_SIZE if limit <= 0

      scope = all
      if order == :desc
        scope = scope.where("#{table_name}.id < ?", after) if after.present?
        scope = scope.where("#{table_name}.id > ?", before) if before.present?
        scope = scope.order(id: :desc)
      else
        scope = scope.where("#{table_name}.id > ?", after) if after.present?
        scope = scope.where("#{table_name}.id < ?", before) if before.present?
        scope = scope.order(id: :asc)
      end

      records = scope.limit(limit + 1).to_a
      has_more = records.size > limit
      records = records.first(limit)

      {
        records: records,
        has_more: has_more,
        cursor: records.last&.id
      }
    end

    # Offset-based pagination with cached total count.
    def offset_paginate(page: 1, per_page: DEFAULT_PAGE_SIZE)
      page    = [page.to_i, 1].max
      per_page = [[per_page.to_i, 1].max, MAX_PAGE_SIZE].min

      records = all.limit(per_page).offset((page - 1) * per_page)
      total   = cached_total_count

      {
        records: records,
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    end

    private

    # Cache the total count for 2 minutes to avoid COUNT(*) on every page load
    def cached_total_count
      cache_key = "#{model_name.cache_key}/total_count/#{all.to_sql.hash}"
      Rails.cache.fetch(cache_key, expires_in: 2.minutes) { all.count }
    end
  end
end
