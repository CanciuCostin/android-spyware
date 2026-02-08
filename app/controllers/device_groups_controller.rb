class DeviceGroupsController < ApplicationController
  before_action :set_device_group, only: [:show, :update, :destroy, :add_devices, :remove_devices, :bulk_command]
  
  def index
    @device_groups = DeviceGroup.all.includes(:devices)
    render json: @device_groups.as_json(
      methods: [:online_count, :total_count, :battery_average, :last_activity],
      include: { devices: { only: [:id, :target_ip, :device_name, :status] } }
    )
  end
  
  def show
    render json: @device_group.as_json(
      methods: [:online_count, :total_count, :battery_average],
      include: { devices: { include: :device_tags } }
    )
  end
  
  def create
    @device_group = DeviceGroup.new(device_group_params)
    
    if @device_group.save
      render json: @device_group, status: :created
    else
      render json: { errors: @device_group.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @device_group.update(device_group_params)
      render json: @device_group
    else
      render json: { errors: @device_group.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @device_group.destroy
    head :no_content
  end
  
  # POST /device_groups/:id/add_devices
  def add_devices
    device_ids = params[:device_ids] || []
    devices = ApkInstallation.where(id: device_ids)
    
    devices.each do |device|
      @device_group.devices << device unless @device_group.devices.include?(device)
    end
    
    render json: { added: devices.count, total: @device_group.devices.count }
  end
  
  # POST /device_groups/:id/remove_devices
  def remove_devices
    device_ids = params[:device_ids] || []
    @device_group.device_group_memberships.where(device_id: device_ids).destroy_all
    
    render json: { removed: device_ids.count, total: @device_group.devices.count }
  end
  
  # POST /device_groups/:id/bulk_command
  def bulk_command
    command_type = params[:command_type]
    command_params = params[:command_params] || {}
    
    results = []
    @device_group.devices.where(status: 'online').each do |device|
      # Send command using CommandSender
      pending_command = PendingCommand.create!(
        command: command_type,
        metadata: command_params,
        device_id: device.id,
        status: 'pending'
      )
      
      ActionCable.server.broadcast(
        "commands_#{device.target_ip}",
        { command: command_type, params: command_params, request_id: pending_command.id }
      )
      
      results << { device_id: device.id, status: 'sent', request_id: pending_command.id }
    end
    
    render json: { sent: results.count, results: results }
  end
  
  private
  
  def set_device_group
    @device_group = DeviceGroup.find(params[:id])
  end
  
  def device_group_params
    params.require(:device_group).permit(:name, :description, :color, metadata: {})
  end
end
