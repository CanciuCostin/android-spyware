class AdminUser < ApplicationRecord
  include Auditable
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable
  
  has_many :audit_logs, dependent: :restrict_with_error
  has_one :user_preference, dependent: :destroy
  has_one :admin_two_factor, dependent: :destroy
  has_many :admin_sessions, dependent: :destroy
  has_many :remembered_devices, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  
  # Track login/logout for audit trail
  after_commit :audit_login, on: :update, if: :saved_change_to_last_sign_in_at?

  # Invalidate all active sessions when password is changed
  after_update :invalidate_sessions_on_password_change, if: :saved_change_to_encrypted_password?
  
  private
  
  def invalidate_sessions_on_password_change
    admin_sessions.destroy_all
    remembered_devices.destroy_all
  end

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
