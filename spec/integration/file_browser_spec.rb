# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'File Browser Feature', type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:smartphone) { create(:smartphone, device_id: 'test_device_123') }
  
  before do
    sign_in admin_user
  end
  
  describe 'GET /api/smartphones/:smartphone_id/files' do
    it 'sends list_files command to device' do
      get "/api/smartphones/#{smartphone.id}/files", params: { path: '/sdcard' }
      
      expect(response).to have_http_status(:accepted)
      expect(JSON.parse(response.body)['success']).to be true
    end
  end
  
  describe 'Security' do
    it 'sanitizes file paths' do
      expect {
        get "/api/smartphones/#{smartphone.id}/files", params: { path: '../../../etc/passwd' }
      }.to raise_error(SecurityError)
    end
  end
end
