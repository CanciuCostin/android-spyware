require 'resolv'

class ApkPayload < ApplicationRecord
  validates :name, presence: true, length: { within: 3..50 }, format: { with: /\A[a-zA-Z0-9_\-]+\z/, message: "only allows letters, numbers, underscores and dashes" }
  validates :destination_ip, presence: true, format: { with: Resolv::IPv4::Regex }
  validates :destination_port, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 65535 }
end
