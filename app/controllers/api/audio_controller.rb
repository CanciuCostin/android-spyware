# frozen_string_literal: true

module Api
  class AudioController < Api::BaseController
    before_action :set_device

    # POST /api/devices/:id/audio/transcribe
    def transcribe
      recording = find_recording
      return render json: { error: 'Recording not found' }, status: :not_found unless recording

      options = {
        transcribe: true,
        speakers: params[:speakers] != 'false',
        keywords: parse_keywords,
        language: params[:language]
      }

      result = AudioIntelligenceService.call(recording, options)
      render json: { status: 'success', data: result }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("[AudioController] Transcribe error: #{e.message}")
      render json: { error: 'Transcription failed' }, status: :internal_server_error
    end

    # GET /api/devices/:id/audio/transcriptions
    def transcriptions
      recording_ids = @device.recordings.pluck(:id)
      transcriptions = AudioTranscription
        .where(recording_id: recording_ids)
        .order(created_at: :desc)
        .limit(params[:limit] || 50)
        .offset(params[:offset] || 0)

      render json: {
        status: 'success',
        total: AudioTranscription.where(recording_id: recording_ids).count,
        data: transcriptions.map { |t| serialize_transcription(t) }
      }
    end

    # POST /api/devices/:id/audio/analyze
    def analyze
      recording = find_recording
      return render json: { error: 'Recording not found' }, status: :not_found unless recording

      options = {
        transcribe: true,
        speakers: true,
        keywords: parse_keywords,
        language: params[:language]
      }

      result = AudioIntelligenceService.call(recording, options)
      render json: { status: 'success', data: result }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("[AudioController] Analyze error: #{e.message}")
      render json: { error: 'Analysis failed' }, status: :internal_server_error
    end

    private

    def set_device
      device_id = sanitize_device_id(params[:id])
      @device = Smartphone.find_by(device_id: device_id) || Smartphone.find_by(id: params[:id])
      render json: { error: 'Device not found' }, status: :not_found unless @device
    end

    def find_recording
      if params[:recording_id]
        @device.recordings.find_by(id: params[:recording_id])
      else
        @device.recordings.order(created_at: :desc).first
      end
    end

    def parse_keywords
      return nil unless params[:keywords].present?

      if params[:keywords].is_a?(Array)
        params[:keywords]
      else
        params[:keywords].to_s.split(',').map(&:strip)
      end
    end

    def serialize_transcription(transcription)
      {
        id: transcription.id,
        recording_id: transcription.recording_id,
        text: transcription.text,
        language: transcription.language,
        confidence: transcription.confidence,
        speakers: parse_json_field(transcription.speakers),
        keywords: parse_json_field(transcription.keywords),
        created_at: transcription.created_at
      }
    end

    def parse_json_field(value)
      return value if value.is_a?(Array) || value.is_a?(Hash)
      return [] if value.blank?

      JSON.parse(value)
    rescue JSON::ParserError
      []
    end
  end
end
