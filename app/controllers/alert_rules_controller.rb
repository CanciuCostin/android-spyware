class AlertRulesController < ApplicationController
  before_action :set_alert_rule, only: [:show, :update, :destroy, :toggle]
  
  def index
    @alert_rules = AlertRule.all.order(created_at: :desc)
    render json: @alert_rules
  end
  
  def show
    render json: @alert_rule
  end
  
  def create
    @alert_rule = AlertRule.new(alert_rule_params)
    
    if @alert_rule.save
      render json: @alert_rule, status: :created
    else
      render json: { errors: @alert_rule.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @alert_rule.update(alert_rule_params)
      render json: @alert_rule
    else
      render json: { errors: @alert_rule.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @alert_rule.destroy
    head :no_content
  end
  
  def toggle
    @alert_rule.update(enabled: !@alert_rule.enabled)
    render json: @alert_rule
  end
  
  private
  
  def set_alert_rule
    @alert_rule = AlertRule.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Alert rule not found' }, status: :not_found
  end
  
  def alert_rule_params
    params.require(:alert_rule).permit(
      :name,
      :event_type,
      :enabled,
      :cooldown_minutes,
      conditions: {},
      notification_channels: [],
      metadata: {}
    )
  end
end
