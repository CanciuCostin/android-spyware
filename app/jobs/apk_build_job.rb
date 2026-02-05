# frozen_string_literal: true

class ApkBuildJob < ApplicationJob
  queue_as :default
  
  # Retry up to 3 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(apk_payload_id)
    payload = ApkPayload.find(apk_payload_id)
    build_apk(payload)
  end
  
  private
  
  def build_apk(payload)
    # Define paths
    android_root = Rails.root.join('../android-client')
    build_log_path = Rails.root.join('log', "apk_build_#{payload.id}.log")
    
    # Sanitize payload name to prevent path traversal
    safe_name = payload.name.to_s.gsub(/[^0-9A-Za-z.\-_]/, '_')
    safe_name = "payload_#{payload.id}" if safe_name.empty?

    # 1. Run Gradle Build with Property Injection (Win/Lin compat)
    gradle_cmd = Gem.win_platform? ? 'gradlew.bat' : './gradlew'
    server_address = "#{payload.destination_ip}:#{payload.destination_port}"
    
    # Pass server config via -P flag to avoid modifying source files (Thread-safe)
    command = "cd \"#{android_root}\" && #{gradle_cmd} assembleRelease -PserverBaseUrl=\"#{server_address}\""
    
    output = ""
    success = false
    
    begin
      # Capture output with timeout
      output = Timeout.timeout(600) do # 10 minute timeout
        `#{command} 2>&1`
      end
      success = $?.success?
    rescue Timeout::Error => e
      output += "\n[Error] Build timeout after 10 minutes"
      success = false
    end

    File.write(build_log_path, output)

    if success
      # 2. Move Artifact
      apk_source = android_root.join('app/build/outputs/apk/release/app-release.apk')
      dest_path = Rails.root.join('public/payloads', "#{safe_name}.apk")
      
      FileUtils.mkdir_p(File.dirname(dest_path))
      if File.exist?(apk_source)
        FileUtils.cp(apk_source, dest_path)
        payload.update(status: 'Completed', name: safe_name)
      else
        payload.update(status: 'Failed (Missing Artifact)')
      end
    else
      payload.update(status: 'Failed (Build Error)')
    end
  rescue StandardError => e
    File.write(build_log_path, "Exception: #{e.message}\n#{e.backtrace.join("\n")}", mode: 'a')
    if payload.respond_to?(:status)
       payload.update_column(:status, 'Error')
    end
    raise # Re-raise for retry logic
  end
end
