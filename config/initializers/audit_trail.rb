# Audit Trail initializer
# Ensures RequestStore is loaded early in the boot process

require 'request_store'

# Configure RequestStore
RequestStore.configure do |config|
  # Use thread-local storage (default)
  # This ensures audit context is properly isolated per request
end

# Hook into ApplicationController to set current admin user
Rails.application.config.to_prepare do
  ApplicationController.class_eval do
    before_action :set_audit_context
    
    private
    
    def set_audit_context
      if respond_to?(:current_admin_user) && current_admin_user
        RequestStore.store[:current_admin_user] = current_admin_user
      end
    rescue => e
      Rails.logger.error "Error setting audit context: #{e.message}"
    end
  end
end
