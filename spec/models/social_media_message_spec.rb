require 'rails_helper'

RSpec.describe SocialMediaMessage, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:body) }
    it { should validate_presence_of(:app_name) }
    it { should validate_presence_of(:sender) }
    it { should validate_presence_of(:sent_at) }
  end

  describe 'associations' do
    it { should belong_to(:smartphone) }
  end

  describe 'scopes' do
    let(:smartphone) { create(:smartphone) }
    let!(:whatsapp_msg) { create(:social_media_message, smartphone: smartphone, app_name: 'WhatsApp', body: 'Hi', sender: 'Mom', sent_at: Time.now) }
    let!(:viber_msg) { create(:social_media_message, smartphone: smartphone, app_name: 'Viber', body: 'Hello', sender: 'Dad', sent_at: Time.now) }
    let!(:telegram_msg) { create(:social_media_message, smartphone: smartphone, app_name: 'Telegram', body: 'Hey', sender: 'Bro', sent_at: Time.now) }
    let!(:facebook_msg) { create(:social_media_message, smartphone: smartphone, app_name: 'Facebook', body: 'Like', sender: 'Sis', sent_at: Time.now) }

    it 'filters by whatsapp' do
      expect(SocialMediaMessage.whatsapp).to include(whatsapp_msg)
      expect(SocialMediaMessage.whatsapp).not_to include(viber_msg)
    end

    it 'filters by viber' do
      expect(SocialMediaMessage.viber).to include(viber_msg)
      expect(SocialMediaMessage.viber).not_to include(whatsapp_msg)
    end

    it 'filters by telegram' do
      expect(SocialMediaMessage.telegram).to include(telegram_msg)
      expect(SocialMediaMessage.telegram).not_to include(whatsapp_msg)
    end

    it 'filters by facebook' do
      expect(SocialMediaMessage.facebook).to include(facebook_msg)
      expect(SocialMediaMessage.facebook).not_to include(whatsapp_msg)
    end
  end
end
