class InstalledApp < ApplicationRecord
  belongs_to :device, class_name: 'ApkInstallation'
  
  validates :package_name, presence: true, uniqueness: { scope: :device_id }
  
  scope :system_apps, -> { where(is_system_app: true) }
  scope :user_apps, -> { where(is_system_app: false) }
  scope :recently_installed, -> { where('install_time > ?', 7.days.ago) }
  scope :recently_updated, -> { where('last_update_time > ?', 7.days.ago) }
  
  # Search by app name or package name
  scope :search, ->(query) {
    where('app_name ILIKE ? OR package_name ILIKE ?', "%#{query}%", "%#{query}%")
  }
  
  # Get apps sorted by various criteria
  scope :by_install_date, -> { order(install_time: :desc) }
  scope :by_update_date, -> { order(last_update_time: :desc) }
  scope :by_name, -> { order(:app_name) }
  
  def formatted_install_time
    install_time&.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def formatted_update_time
    last_update_time&.strftime('%Y-%m-%d %H:%M:%S')
  end
  
  def app_type
    is_system_app ? 'System' : 'User'
  end
end
