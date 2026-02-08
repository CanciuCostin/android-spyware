# frozen_string_literal: true

module Api
  class AiChatController < Api::BaseController
    skip_before_action :authenticate_device!

    # POST /api/ai/chat
    def chat
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      service = AiChatService.new(device, params[:message], history: params[:history])
      result = service.call

      if result.success?
        render json: result.value
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # GET /api/ai/chat/capabilities
    def capabilities
      render json: {
        commands: [
          { pattern: 'Show calls to [name]', description: 'Search call logs by contact' },
          { pattern: 'Show SMS from [contact]', description: 'Search messages' },
          { pattern: 'Where was device yesterday/today', description: 'Location history' },
          { pattern: 'How many SMS/calls/photos', description: 'Count records' },
          { pattern: 'Top contacts', description: 'Most frequent contacts' },
          { pattern: 'Activity summary', description: 'Weekly overview' },
          { pattern: 'App usage', description: 'Top apps by usage' },
          { pattern: 'Risk/anomalies', description: 'Security assessment' }
        ],
        ai_enabled: ENV['OPENAI_API_KEY'].present?,
        version: '1.0'
      }
    end

    private

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end
  end
end
