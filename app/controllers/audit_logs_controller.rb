require 'csv'

class AuditLogsController < ApplicationController
  skip_before_action :authenticate_admin_user!, raise: false
  before_action :set_audit_log, only: [:show]
  
  # GET /audit_logs
  def index
    @audit_logs = AuditLog
      .includes(:admin_user, :auditable)
      .order(created_at: :desc)
      .page(params[:page])
      .per(50)
    
    @audit_logs = @audit_logs.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?
    @audit_logs = @audit_logs.where(action: params[:action]) if params[:action].present?
    @audit_logs = @audit_logs.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
    
    if params[:start_date].present? && params[:end_date].present?
      start_date = safe_parse_date(params[:start_date])
      end_date = safe_parse_date(params[:end_date])
      @audit_logs = @audit_logs.where(created_at: start_date.beginning_of_day..end_date.end_of_day) if start_date && end_date
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @audit_logs.as_json(include: [:admin_user, :auditable]) }
    end
  end
  
  # GET /audit_logs/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: @audit_log.as_json(include: [:admin_user, :auditable]) }
    end
  end
  
  # GET /audit_logs/export
  def export
    @audit_logs = AuditLog.includes(:admin_user, :auditable)
    
    # Apply filters
    @audit_logs = @audit_logs.where(admin_user_id: params[:admin_user_id]) if params[:admin_user_id].present?
    @audit_logs = @audit_logs.where(action: params[:action]) if params[:action].present?
    @audit_logs = @audit_logs.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
    
    if params[:start_date].present? && params[:end_date].present?
      start_date = safe_parse_date(params[:start_date])
      end_date = safe_parse_date(params[:end_date])
      @audit_logs = @audit_logs.where(created_at: start_date.beginning_of_day..end_date.end_of_day) if start_date && end_date
    end
    
    @audit_logs = @audit_logs.order(created_at: :desc)
    
    respond_to do |format|
      format.csv do
        send_data to_csv(@audit_logs), 
                  filename: "audit_trail_#{Date.today}.csv",
                  type: 'text/csv',
                  disposition: 'attachment'
      end
      format.json do
        send_data @audit_logs.to_json(include: [:admin_user, :auditable]), 
                  filename: "audit_trail_#{Date.today}.json",
                  type: 'application/json',
                  disposition: 'attachment'
      end
    end
  end
  
  # GET /audit_logs/stats
  def stats
    start_date = params[:start_date] ? safe_parse_date(params[:start_date], 30.days.ago) : 30.days.ago
    end_date = params[:end_date] ? safe_parse_date(params[:end_date], Date.today) : Date.today
    
    logs = AuditLog.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    
    stats = {
      total_actions: logs.count,
      by_action: logs.group(:action).count,
      by_user: logs.joins(:admin_user).group('admin_users.email').count,
      by_resource_type: logs.group(:auditable_type).count,
      by_day: logs.group_by_day(:created_at, format: "%Y-%m-%d").count,
      unique_admins: logs.distinct.count(:admin_user_id),
      unique_ips: logs.where.not(ip_address: nil).distinct.count(:ip_address)
    }
    
    render json: stats
  end
  
  private
  
  def safe_parse_date(str, default = nil)
    Date.parse(str.to_s)
  rescue ArgumentError, TypeError
    default
  end

  def set_audit_log
    @audit_log = AuditLog.find(params[:id])
  end
  
  def authenticate_admin_user!
    # Store current admin user for audit trail
    if respond_to?(:current_admin_user) && current_admin_user
      RequestStore.store[:current_admin_user] = current_admin_user
    end
    
    # Implement your authentication logic here
    # For ActiveAdmin, it's typically handled automatically
  end
  
  def to_csv(audit_logs)
    CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Admin User', 'Action', 'Auditable Type', 'Auditable ID', 
              'IP Address', 'Request Method', 'Request Path', 'Response Status', 
              'Changes', 'Created At']
      
      audit_logs.each do |log|
        csv << [
          log.id,
          log.admin_user&.email || 'System',
          log.action,
          log.auditable_type,
          log.auditable_id,
          log.ip_address,
          log.request_method,
          log.request_path,
          log.response_status,
          log.changes.to_json,
          log.created_at.iso8601
        ]
      end
    end
  end
end
