# frozen_string_literal: true

class WifiNetwork < ApplicationRecord
  belongs_to :smartphone

  validates :ssid, presence: true

  scope :connected, -> { where(is_connected: true) }
  scope :saved, -> { where(is_saved: true) }
  scope :recent, -> { order(last_connected_at: :desc) }
end
