class AuditLog < ApplicationRecord
  belongs_to :admin_user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true
  
  validates :action, presence: true, inclusion: { in: %w[create read update delete login logout] }
  
  # Prevent updates and deletes through Rails
  before_update { raise ActiveRecord::ReadOnlyRecord, 'Audit logs are immutable' }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, 'Audit logs are immutable' }
  
  scope :by_action, ->(action) { where(action: action) }
  scope :by_admin, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_type, ->(type) { where(auditable_type: type) }
  scope :in_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :recent, -> { order(created_at: :desc) }
  
  def self.search(params = {})
    logs = all
    logs = logs.by_action(params[:action]) if params[:action].present?
    logs = logs.by_admin(params[:admin_user_id]) if params[:admin_user_id].present?
    logs = logs.by_type(params[:auditable_type]) if params[:auditable_type].present?
    logs = logs.in_date_range(params[:start_date], params[:end_date]) if params[:start_date] && params[:end_date]
    logs.recent
  end
  
  def readonly?
    persisted?
  end
end
