class AdminUser < ApplicationRecord
  include Auditable
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable
  
  has_many :audit_logs, dependent: :restrict_with_error
  has_one :user_preference, dependent: :destroy
  
  # Track login/logout for audit trail
  after_commit :audit_login, on: :update, if: :saved_change_to_last_sign_in_at?
  
  private
  
  def audit_login
    AuditService.log(
      action: 'login',
      auditable: self,
      admin_user: self,
      metadata: { 
        login_count: sign_in_count,
        last_ip: last_sign_in_ip
      }
    )
  end
end
