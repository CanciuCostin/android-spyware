class StatisticsController < ApplicationController
  include ResponseFormatter
  before_action :set_device, only: [:show]
  
  def show
    days_range = params[:days]&.to_i || 30
    
    @stats = Rails.cache.fetch("device_stats/#{@device.id}/#{days_range}", expires_in: 5.minutes) do
      StatisticsService.new(@device, days_range: days_range).calculate
    end
    
    render_success(@stats)
  end
  
  private
  
  def set_device
    @device = Smartphone.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found('Device not found')
  end
end
