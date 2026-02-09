class CallLog < ApplicationRecord
  belongs_to :smartphone
  
  validates :smartphone_id, presence: true
  validates :filename, presence: true
  validates :date, presence: true
end
