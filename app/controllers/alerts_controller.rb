class AlertsController < ApplicationController
  before_action :set_alert, only: [:show, :acknowledge]
  
  def index
    @alerts = Alert.includes(:alert_rule, :device)
                   .order(triggered_at: :desc)
    
    @alerts = @alerts.where(severity: params[:severity]) if params[:severity].present?
    @alerts = @alerts.where(device_id: params[:device_id]) if params[:device_id].present?
    @alerts = @alerts.unacknowledged if params[:unacknowledged] == 'true'
    
    @alerts = @alerts.page(params[:page]).per(params[:per_page] || 20)
    
    render json: {
      alerts: @alerts,
      meta: {
        current_page: @alerts.current_page,
        total_pages: @alerts.total_pages,
        total_count: @alerts.total_count
      }
    }
  end
  
  def show
    render json: @alert, include: [:alert_rule, :device, :notification_logs]
  end
  
  def acknowledge
    if @alert.acknowledge!(current_admin_user)
      render json: @alert
    else
      render json: { error: 'Failed to acknowledge alert' }, status: :unprocessable_entity
    end
  end
  
  def stats
    stats = {
      total: Alert.count,
      unacknowledged: Alert.unacknowledged.count,
      by_severity: Alert.group(:severity).count,
      recent_24h: Alert.where('triggered_at > ?', 24.hours.ago).count,
      by_event_type: Alert.joins(:alert_rule).group('alert_rules.event_type').count
    }
    
    render json: stats
  end
  
  private
  
  def set_alert
    @alert = Alert.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alert not found' }, status: :not_found
  end
  
  def current_admin_user
    # This should be implemented based on your auth system
    # For now, returning first admin user
    AdminUser.first
  end
end
