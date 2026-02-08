# frozen_string_literal: true

class Certificate < ApplicationRecord
  belongs_to :smartphone

  validates :subject, presence: true

  scope :system_certs, -> { where(is_system: true) }
  scope :user_certs, -> { where(is_system: false) }
  scope :trusted, -> { where(is_trusted: true) }
  scope :valid_now, -> { where('valid_to IS NULL OR valid_to > ?', Time.current) }
end
