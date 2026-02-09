class AppControlController < ApplicationController
  before_action :set_device
  
  # GET /devices/:device_id/apps
  def index
    apps = @device.installed_apps.order(:app_name)
    render json: apps
  end
  
  # POST /devices/:device_id/apps/refresh
  def refresh
    command = {
      type: 'list_installed_apps',
      device_id: @device.id
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'list_installed_apps',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'refreshing',
      request_id: pending_command.id
    }
  end
  
  # POST /devices/:device_id/apps/install
  def install
    apk_url = params[:apk_url]
    package_name = params[:package_name]
    
    command = {
      type: 'install_app',
      apk_url: apk_url,
      package_name: package_name
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'install_app',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'installing',
      request_id: pending_command.id
    }
  end
  
  # DELETE /devices/:device_id/apps/:package_name
  def uninstall
    package_name = params[:package_name]
    
    command = {
      type: 'uninstall_app',
      package_name: package_name
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'uninstall_app',
      command_data: command,
      status: 'pending'
    )
    
    render json: {
      status: 'uninstalling',
      request_id: pending_command.id
    }
  end
  
  # POST /devices/:device_id/apps/:package_name/launch
  def launch
    package_name = params[:package_name]
    
    command = {
      type: 'launch_app',
      package_name: package_name
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'launch_app',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'launching',
      request_id: pending_command.id
    }
  end
  
  # POST /devices/:device_id/apps/:package_name/kill
  def kill
    package_name = params[:package_name]
    
    command = {
      type: 'kill_app',
      package_name: package_name
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'kill_app',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'killing',
      request_id: pending_command.id
    }
  end
  
  # GET /devices/:device_id/processes
  def processes
    command = {
      type: 'list_processes'
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'list_processes',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'fetching',
      request_id: pending_command.id
    }
  end
  
  # GET /devices/:device_id/apps/:package_name/permissions
  def permissions
    package_name = params[:package_name]
    app = @device.installed_apps.find_by(package_name: package_name)
    
    if app
      render json: { permissions: app.permissions || [] }
    else
      render json: { error: 'App not found' }, status: :not_found
    end
  end
  
  # PATCH /devices/:device_id/apps/:package_name/permissions
  def update_permissions
    package_name = params[:package_name]
    permissions = params[:permissions] # Array of permission names
    grant = params[:grant] # true to grant, false to revoke
    
    command = {
      type: 'manage_permissions',
      package_name: package_name,
      permissions: permissions,
      grant: grant
    }
    
    pending_command = @device.pending_commands.create!(
      command_type: 'manage_permissions',
      command_data: command,
      status: 'pending'
    )
    
    render json: { 
      status: 'updating_permissions',
      request_id: pending_command.id
    }
  end
  
  private
  
  def set_device
    @device = ApkInstallation.find(params[:device_id])
  end
end
