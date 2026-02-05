class Contact < ApplicationRecord
  belongs_to :smartphone
  
  validates :smartphone_id, presence: true
end
