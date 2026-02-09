class DataRetentionJob < ApplicationJob
  queue_as :low_priority

  def perform(smartphone_id: nil, overrides: {})
    Rails.logger.info("[DataRetentionJob] Starting data retention enforcement")

    smartphone = Smartphone.find(smartphone_id) if smartphone_id
    service = DataRetentionService.new(smartphone: smartphone, overrides: overrides)
    result = service.enforce_all_policies

    if result.success?
      summary = result.value
      Rails.logger.info(
        "[DataRetentionJob] Completed: #{summary[:total_deleted]} records deleted. " \
        "Breakdown: #{summary[:deleted].map { |k, v| "#{k}=#{v}" }.join(', ')}"
      )

      if summary[:errors].any?
        Rails.logger.warn("[DataRetentionJob] Errors: #{summary[:errors].map { |e| e[:data_type] }.join(', ')}")
      end
    else
      Rails.logger.error("[DataRetentionJob] Failed: #{result.error}")
    end
  rescue => e
    Rails.logger.error("[DataRetentionJob] Unhandled error: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise # Re-raise for ActiveJob retry
  end
end
