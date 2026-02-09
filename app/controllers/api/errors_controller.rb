# frozen_string_literal: true

module Api
  class ErrorsController < BaseController
    skip_before_action :authenticate_device!, only: [:index, :show, :resolve, :ignore]
    before_action :authenticate_admin!, only: [:index, :show, :resolve, :ignore]
    before_action :set_tracked_error, only: [:show, :resolve, :ignore]

    # GET /api/errors
    def index
      errors = ErrorAggregator.summary(
        status: params[:status],
        limit: (params[:limit] || 50).to_i,
        order: params[:order] || :recent
      )

      render json: {
        errors: errors.map { |e| serialize_error(e) },
        stats: ErrorAggregator.stats
      }
    end

    # GET /api/errors/:id
    def show
      render json: serialize_error(@tracked_error, detailed: true)
    end

    # PUT /api/errors/:id/resolve
    def resolve
      @tracked_error.resolve!
      render json: { status: 'resolved', error: serialize_error(@tracked_error) }
    end

    # PUT /api/errors/:id/ignore
    def ignore
      @tracked_error.ignore!
      render json: { status: 'ignored', error: serialize_error(@tracked_error) }
    end

    private

    def authenticate_admin!
      unless current_admin_user
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end

    def current_admin_user
      @current_admin_user ||= begin
        return env['warden']&.user(:admin_user) if defined?(env) && env['warden']
        nil
      end
    end

    def set_tracked_error
      @tracked_error = TrackedError.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Error not found' }, status: :not_found
    end

    def serialize_error(error, detailed: false)
      data = {
        id: error.id,
        fingerprint: error.fingerprint,
        error_class: error.error_class,
        message: error.message,
        count: error.count,
        status: error.status,
        first_seen_at: error.first_seen_at&.iso8601,
        last_seen_at: error.last_seen_at&.iso8601,
        affected_devices: error.affected_device_count
      }

      if detailed
        data[:backtrace] = error.backtrace
        data[:device_ids] = error.device_ids
        data[:resolved_at] = error.resolved_at&.iso8601
        data[:created_at] = error.created_at&.iso8601
        data[:updated_at] = error.updated_at&.iso8601
      end

      data
    end
  end
end
