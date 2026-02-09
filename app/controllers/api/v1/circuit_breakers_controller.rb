# frozen_string_literal: true

module Api
  module V1
    class CircuitBreakersController < Api::BaseController
      VALID_SERVICES = %w[google_vision openai_vision google_maps_geocoding].freeze

      before_action :authenticate_admin_user!
      skip_before_action :authenticate_device!
      before_action :validate_service!, only: :reset

      # GET /api/v1/circuit_breakers
      def index
        render json: {
          metrics: CircuitBreaker.all_metrics,
          timestamp: Time.current.iso8601
        }
      end

      # POST /api/v1/circuit_breakers/:service/reset
      def reset
        cb = CircuitBreaker.for(@service_name)
        cb.reset!
        
        render json: { status: 'ok', service: @service_name, metrics: cb.metrics }
      end

      private

      def validate_service!
        @service_name = params[:service]
        return if VALID_SERVICES.include?(@service_name)

        render json: { error: 'Invalid service name' }, status: :unprocessable_entity
      end
    end
  end
end
