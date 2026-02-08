module Auditable
  extend ActiveSupport::Concern
  
  included do
    after_create :audit_create
    after_update :audit_update
    after_destroy :audit_destroy
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
