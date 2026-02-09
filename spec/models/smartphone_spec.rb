require 'rails_helper'

RSpec.describe Smartphone, type: :model do
  context 'validations' do
    it 'creates a valid smartphone' do
      smartphone = Smartphone.create(
        name: "Test Phone",
        operating_system: "Android 10",
        is_rooted: false,
        is_app_hidden: true
      )
      expect(smartphone).to be_valid
    end
  end

  context 'associations' do
    it 'can have recordings' do
      smartphone = Smartphone.create(name: "Test Phone for Recordings")
      recording = Recording.create(
        smartphone: smartphone, 
        filename: "rec.mp3", 
        date: Time.now
      )
      expect(smartphone.recordings).to include(recording)
    end
  end
end
