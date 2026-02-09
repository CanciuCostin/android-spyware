class DeviceTagsController < ApplicationController
  before_action :set_device, except: [:search]
  
  # GET /devices/:device_id/tags
  def index
    render json: @device.device_tags
  end
  
  # POST /devices/:device_id/tags
  def create
    @tag = @device.device_tags.create_or_find_by!(key: params[:key])
    @tag.update(value: params[:value])
    
    render json: @tag, status: :created
  end
  
  # DELETE /devices/:device_id/tags/:key
  def destroy
    @device.device_tags.where(key: params[:key]).destroy_all
    head :no_content
  end
  
  # GET /devices/tags/search?key=environment&value=production
  def search
    tags = DeviceTag.with_tag(params[:key], params[:value])
    devices = ApkInstallation.where(id: tags.select(:device_id))
    
    render json: devices
  end
  
  private
  
  def set_device
    @device = ApkInstallation.find(params[:device_id])
  end
end
