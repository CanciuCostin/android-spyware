module Auditable
  extend ActiveSupport::Concern
  
  included do
    after_commit :audit_create, on: :create
    after_commit :audit_update, on: :update
    after_commit :audit_destroy, on: :destroy
  end
  
  private
  
  def audit_create
    AuditService.log(
      action: 'create',
      auditable: self,
      changes: { after: auditable_attributes }
    )
  end
  
  def audit_update
    return unless saved_changes.any?
    
    AuditService.log(
      action: 'update',
      auditable: self,
      changes: {
        before: saved_changes.transform_values(&:first),
        after: saved_changes.transform_values(&:last)
      }
    )
  end
  
  def audit_destroy
    AuditService.log(
      action: 'delete',
      auditable: self,
      changes: { before: auditable_attributes }
    )
  end
  
  def auditable_attributes
    attributes.except('created_at', 'updated_at')
  end
end
