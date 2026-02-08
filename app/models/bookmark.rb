# frozen_string_literal: true

class Bookmark < ApplicationRecord
  belongs_to :smartphone

  validates :url, presence: true

  scope :by_browser, ->(browser) { where(browser: browser) if browser.present? }
  scope :recent, -> { order(bookmarked_at: :desc) }
end
