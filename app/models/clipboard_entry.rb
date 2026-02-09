# frozen_string_literal: true

class ClipboardEntry < ApplicationRecord
  belongs_to :smartphone

  validates :content, presence: true
  validates :captured_at, presence: true

  scope :recent, -> { order(captured_at: :desc) }
  scope :by_app, ->(app) { where(source_app: app) if app.present? }
end
