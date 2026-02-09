class Recording < ApplicationRecord
  belongs_to :smartphone
  has_many :audio_transcriptions, dependent: :destroy
  
  validates :smartphone_id, presence: true
  validates :filename, presence: true
  validates :date, presence: true
end
