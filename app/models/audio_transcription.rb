# frozen_string_literal: true

class AudioTranscription < ApplicationRecord
  belongs_to :recording

  validates :recording_id, presence: true
  validates :text, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_language, ->(lang) { where(language: lang) }
  scope :with_keywords, -> { where.not(keywords: [nil, '[]', '']) }
end
