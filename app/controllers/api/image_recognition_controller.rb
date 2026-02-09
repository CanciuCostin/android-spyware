# frozen_string_literal: true

module Api
  class ImageRecognitionController < Api::BaseController
    skip_before_action :authenticate_device!

    # POST /api/ai/image/analyze
    def analyze
      image_path = resolve_image_path
      return render json: { error: 'Image path or URL is required' }, status: :bad_request unless image_path

      service = ImageRecognitionService.new(image_path)
      result = service.call

      if result.success?
        render json: { analysis: result.value }
      else
        render json: { error: result.error }, status: :unprocessable_entity
      end
    end

    # POST /api/ai/image/ocr
    def ocr
      image_path = resolve_image_path
      return render json: { error: 'Image path or URL is required' }, status: :bad_request unless image_path

      service = ImageRecognitionService.new(image_path)
      render json: { ocr: service.extract_text }
    end

    # POST /api/ai/image/faces
    def faces
      image_path = resolve_image_path
      return render json: { error: 'Image path or URL is required' }, status: :bad_request unless image_path

      service = ImageRecognitionService.new(image_path)
      render json: { faces: service.detect_faces }
    end

    # POST /api/ai/image/objects
    def objects
      image_path = resolve_image_path
      return render json: { error: 'Image path or URL is required' }, status: :bad_request unless image_path

      service = ImageRecognitionService.new(image_path)
      render json: { objects: service.detect_objects }
    end

    # POST /api/ai/image/metadata
    def metadata
      image_path = resolve_image_path
      return render json: { error: 'Image path or URL is required' }, status: :bad_request unless image_path

      service = ImageRecognitionService.new(image_path)
      render json: { metadata: service.extract_metadata }
    end

    # GET /api/ai/image/device_images/:device_id
    def device_images
      device = find_device
      return render json: { error: 'Device not found' }, status: :not_found unless device

      result = ImageRecognitionService.analyze_device_images(device, limit: (params[:limit] || 20).to_i)
      render json: { device_id: device.device_id, image_analysis: result }
    end

    private

    def resolve_image_path
      if params[:image].respond_to?(:tempfile)
        params[:image].tempfile.path
      elsif params[:image_path].present?
        params[:image_path]
      elsif params[:image_url].present?
        params[:image_url]
      end
    end

    def find_device
      Smartphone.find_by(id: params[:device_id]) || Smartphone.find_by(device_id: params[:device_id])
    end
  end
end
