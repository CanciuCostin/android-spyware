class Screenshot < ApplicationRecord
  belongs_to :smartphone

  validates :smartphone_id, presence: true
  validates :filename, presence: true, if: -> { respond_to?(:filename) }
end
