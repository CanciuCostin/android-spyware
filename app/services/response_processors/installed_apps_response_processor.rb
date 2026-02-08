class InstalledAppsResponseProcessor
  def initialize(pending_command, response)
    @pending_command = pending_command
    @response = response
    @device = pending_command.device
  end
  
  def process
    apps_data = @response['apps'] || []
    
    ActiveRecord::Base.transaction do
      # Update or create installed apps
      apps_data.each do |app_data|
        app = @device.installed_apps.find_or_initialize_by(
          package_name: app_data['packageName']
        )
        
        app.update!(
          app_name: app_data['appName'],
          version_name: app_data['versionName'],
          version_code: app_data['versionCode'],
          is_system_app: app_data['isSystemApp'],
          install_time: Time.at(app_data['installTime'] / 1000),
          last_update_time: Time.at(app_data['lastUpdateTime'] / 1000),
          permissions: app_data['permissions'] || []
        )
      end
      
      # Remove apps that are no longer installed
      current_packages = apps_data.map { |a| a['packageName'] }
      @device.installed_apps.where.not(package_name: current_packages).destroy_all
      
      mark_completed
    end
  rescue StandardError => e
    mark_failed(e.message)
  end
  
  private
  
  def mark_completed
    @pending_command.update!(
      status: 'completed',
      completed_at: Time.current,
      response_data: @response
    )
  end
  
  def mark_failed(error_message)
    @pending_command.update!(
      status: 'failed',
      completed_at: Time.current,
      error_message: error_message
    )
  end
end
