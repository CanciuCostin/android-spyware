# frozen_string_literal: true

# Shared concern for finding or creating smartphone records
# Eliminates DRY violation across API controllers
module Api
  module SmartphoneFinder
    extend ActiveSupport::Concern
    
    private
    
    # Sanitize device_id to prevent path traversal attacks
    def sanitize_device_id(device_id)
      sanitized = device_id.to_s.gsub(/[^a-zA-Z0-9_.:\-]/, '')
      sanitized.length > 128 ? sanitized[0, 128] : sanitized
    end
    
    # Find existing smartphone or create new one with proper associations
    # Thread-safe implementation using database-level uniqueness
    def find_or_create_smartphone(device_id)
      safe_id = sanitize_device_id(device_id)
      return nil if safe_id.blank?

      smartphone = Smartphone.find_by(device_id: safe_id)
      return smartphone if smartphone
      
      # Create with proper locking to avoid race conditions
      ActiveRecord::Base.transaction do
        # Double-check inside transaction
        smartphone = Smartphone.find_by(device_id: safe_id)
        return smartphone if smartphone
        
        # Create default payload and installation
        payload = ApkPayload.find_or_create_by!(name: 'default') do |p|
          p.destination_ip = '0.0.0.0'
          p.destination_port = '8080'
        end
        
        installation = ApkInstallation.find_or_create_by!(
          apk_payload: payload,
          target_ip: safe_id
        ) do |i|
          i.status = 'active'
        end
        
        Smartphone.create!(
          device_id: safe_id,
          name: "Device #{safe_id[0..7]}",
          apk_installation: installation,
          operating_system: 'Android'
        )
      end
    rescue ActiveRecord::RecordNotUnique
      # Handle race condition - record was created by another thread
      Smartphone.find_by!(device_id: safe_id)
    end
  end
end
