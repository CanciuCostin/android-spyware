# frozen_string_literal: true

module Api
  class NlpAnalysisController < Api::BaseController
    skip_before_action :authenticate_device!

    # POST /api/ai/nlp/analyze
    def analyze
      return render json: { error: 'Text is required' }, status: :bad_request if params[:text].blank?

      service = NlpAnalysisService.new(params[:text])
      result = service.call

      if result.success?
        render json: { analysis: result.value }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # POST /api/ai/nlp/entities
    def entities
      return render json: { error: 'Text is required' }, status: :bad_request if params[:text].blank?

      service = NlpAnalysisService.new(params[:text])
      render json: { entities: service.extract_entities }
    end

    # POST /api/ai/nlp/sentiment
    def sentiment
      return render json: { error: 'Text is required' }, status: :bad_request if params[:text].blank?

      service = NlpAnalysisService.new(params[:text])
      render json: { sentiment: service.analyze_sentiment }
    end

    # POST /api/ai/nlp/language
    def language
      return render json: { error: 'Text is required' }, status: :bad_request if params[:text].blank?

      service = NlpAnalysisService.new(params[:text])
      render json: { language: service.detect_language }
    end

    # POST /api/ai/nlp/pii
    def pii
      return render json: { error: 'Text is required' }, status: :bad_request if params[:text].blank?

      service = NlpAnalysisService.new(params[:text])
      render json: { pii: service.detect_pii }
    end

    # GET /api/ai/nlp/device_messages/:device_id
    def device_messages
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      result = NlpAnalysisService.analyze_device_messages(device, limit: (params[:limit] || 100).to_i)
      render json: { device_id: device.device_id, nlp_analysis: result }
    end

    private

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end
  end
end
