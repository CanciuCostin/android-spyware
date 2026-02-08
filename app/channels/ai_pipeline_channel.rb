# frozen_string_literal: true

class AiPipelineChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]

    if device_id.present?
      stream_from "ai_pipeline:#{device_id}"
    else
      stream_from "ai_pipeline:global"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Client can request current pipeline status
  def request_status
    device_id = params[:device_id]
    pipeline = AiPipeline::PipelineManager.new
    transmit({ event: 'status', data: pipeline.status })
  end
end
