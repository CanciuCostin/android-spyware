# frozen_string_literal: true

# Groups similar errors by fingerprint and tracks frequency/device impact.
#
# Usage:
#   ErrorAggregator.track(exception, device_id: "abc123")
#   ErrorAggregator.summary(status: 'open', limit: 20)
#   ErrorAggregator.auto_resolve_stale!
class ErrorAggregator
  class << self
    def track(exception, context = {})
      fingerprint = generate_fingerprint(exception)
      device_id = context[:device_id]

      existing = TrackedError.find_by(fingerprint: fingerprint)

      if existing
        existing.increment_occurrence!(
          new_backtrace: clean_backtrace(exception),
          device_id: device_id
        )
        existing
      else
        TrackedError.create!(
          fingerprint: fingerprint,
          error_class: exception.class.name,
          message: exception.message.to_s.truncate(500),
          backtrace: clean_backtrace(exception),
          count: 1,
          first_seen_at: Time.current,
          last_seen_at: Time.current,
          status: 'open',
          device_ids: device_id.present? ? [device_id] : []
        )
      end
    rescue => e
      Rails.logger.error("[ErrorAggregator] Failed to track error: #{e.message}")
      nil
    end

    def summary(status: nil, limit: 50, order: :recent)
      scope = TrackedError.all
      scope = scope.where(status: status) if status.present?

      case order.to_sym
      when :frequent
        scope = scope.most_frequent
      else
        scope = scope.recent
      end

      scope.limit(limit)
    end

    def stats
      {
        total: TrackedError.count,
        open: TrackedError.open_errors.count,
        resolved: TrackedError.resolved.count,
        ignored: TrackedError.ignored.count,
        total_occurrences: TrackedError.sum(:count),
        top_errors: TrackedError.open_errors.most_frequent.limit(5).map do |e|
          { error_class: e.error_class, message: e.message.truncate(100), count: e.count }
        end
      }
    end

    def auto_resolve_stale!
      count = TrackedError.stale.count
      TrackedError.auto_resolve_stale!
      Rails.logger.info("[ErrorAggregator] Auto-resolved #{count} stale errors") if count > 0
      count
    end

    private

    def generate_fingerprint(exception)
      components = [
        exception.class.name,
        normalize_message(exception.message),
        exception.backtrace&.first(3)&.join("\n")
      ].compact.join('|')

      Digest::SHA256.hexdigest(components)[0..31]
    end

    def normalize_message(message)
      return '' if message.blank?

      message.to_s
        .gsub(/#<\w+:0x[0-9a-f]+>/, '#<Object>')  # Remove object addresses
        .gsub(/\b\d+\b/, 'N')                        # Normalize numbers
        .gsub(/"[^"]*"/, '"..."')                     # Normalize quoted strings
        .truncate(200)
    end

    def clean_backtrace(exception)
      return [] unless exception.backtrace

      exception.backtrace
        .reject { |line| line.include?('/gems/') || line.include?('/ruby/') }
        .first(15)
    end
  end
end
