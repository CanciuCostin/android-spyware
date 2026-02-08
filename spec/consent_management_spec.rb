require 'rails_helper'

RSpec.describe 'Consent Management System', type: :request do
  let(:device) { create(:apk_installation) }
  let(:admin_user) { create(:admin_user) }
  
  before do
    sign_in admin_user
  end
  
  describe 'GET /apk_installations/:device_id/consents' do
    it 'returns all consent statuses' do
      get "/apk_installations/#{device.id}/consents"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']).to be_an(Array)
      expect(json['data'].length).to eq(DeviceConsent::CONSENT_TYPES.length)
    end
  end
  
  describe 'POST /apk_installations/:device_id/consents/grant' do
    it 'grants consent successfully' do
      post "/apk_installations/#{device.id}/consents/grant",
           params: { consent_type: 'device_monitoring' }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['granted']).to be true
      expect(json['message']).to eq('Consent granted')
      
      # Verify in database
      consent = device.device_consents.find_by(consent_type: 'device_monitoring')
      expect(consent.active?).to be true
    end
    
    it 'records audit trail' do
      expect {
        post "/apk_installations/#{device.id}/consents/grant",
             params: { consent_type: 'location_tracking' }
      }.to change { AuditLog.count }.by(1)
    end
  end
  
  describe 'POST /apk_installations/:device_id/consents/revoke' do
    let!(:consent) do
      device.device_consents.create!(
        consent_type: 'microphone_access',
        granted: true,
        granted_at: Time.current
      )
    end
    
    it 'revokes consent successfully' do
      post "/apk_installations/#{device.id}/consents/revoke",
           params: { consent_type: 'microphone_access' }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['granted']).to be false
      expect(json['data']['revoked_at']).not_to be_nil
      
      consent.reload
      expect(consent.active?).to be false
    end
  end
  
  describe 'GET /apk_installations/:device_id/consents/export' do
    it 'exports consent history as JSON' do
      get "/apk_installations/#{device.id}/consents/export"
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/json')
      expect(response.headers['Content-Disposition']).to include('attachment')
      
      json = JSON.parse(response.body)
      expect(json).to have_key('device_id')
      expect(json).to have_key('consents')
      expect(json).to have_key('terms')
      expect(json).to have_key('disclosures')
    end
  end
end

RSpec.describe DeviceConsent, type: :model do
  let(:device) { create(:apk_installation) }
  
  describe 'validations' do
    it 'validates consent_type presence' do
      consent = DeviceConsent.new(device: device)
      expect(consent).not_to be_valid
      expect(consent.errors[:consent_type]).to include("can't be blank")
    end
    
    it 'validates consent_type inclusion' do
      consent = DeviceConsent.new(device: device, consent_type: 'invalid_type')
      expect(consent).not_to be_valid
    end
    
    it 'validates uniqueness of consent_type per device' do
      DeviceConsent.create!(device: device, consent_type: 'device_monitoring')
      duplicate = DeviceConsent.new(device: device, consent_type: 'device_monitoring')
      expect(duplicate).not_to be_valid
    end
  end
  
  describe '#grant!' do
    let(:consent) { device.device_consents.create!(consent_type: 'camera_access') }
    
    it 'grants consent with full metadata' do
      consent.grant!(
        granted_by: 'admin@example.com',
        ip_address: '192.168.1.1',
        consent_text: 'I agree to camera access',
        version: '1.0'
      )
      
      expect(consent.granted?).to be true
      expect(consent.granted_at).not_to be_nil
      expect(consent.granted_by).to eq('admin@example.com')
      expect(consent.ip_address).to eq('192.168.1.1')
      expect(consent.consent_version).to eq('1.0')
      expect(consent.revoked_at).to be_nil
    end
  end
  
  describe '#revoke!' do
    let(:consent) do
      device.device_consents.create!(
        consent_type: 'location_tracking',
        granted: true,
        granted_at: Time.current
      )
    end
    
    it 'revokes consent and sets revoked_at' do
      consent.revoke!
      
      expect(consent.granted?).to be false
      expect(consent.revoked_at).not_to be_nil
    end
  end
  
  describe '#active?' do
    it 'returns true for granted and non-revoked consent' do
      consent = device.device_consents.create!(
        consent_type: 'sms_monitoring',
        granted: true,
        granted_at: Time.current
      )
      expect(consent.active?).to be true
    end
    
    it 'returns false for revoked consent' do
      consent = device.device_consents.create!(
        consent_type: 'sms_monitoring',
        granted: true,
        granted_at: Time.current,
        revoked_at: Time.current
      )
      expect(consent.active?).to be false
    end
  end
end

RSpec.describe ConsentService do
  let(:device) { create(:apk_installation) }
  let(:service) { ConsentService.new(device) }
  
  describe '#grant_consent' do
    it 'grants consent successfully' do
      result = service.grant_consent(
        'device_monitoring',
        granted_by: 'admin@example.com',
        ip_address: '127.0.0.1'
      )
      
      expect(result.success?).to be true
      expect(result.value.active?).to be true
    end
  end
  
  describe '#revoke_consent' do
    before do
      service.grant_consent(
        'microphone_access',
        granted_by: 'admin@example.com',
        ip_address: '127.0.0.1'
      )
    end
    
    it 'revokes consent successfully' do
      result = service.revoke_consent('microphone_access')
      
      expect(result.success?).to be true
      expect(result.value.active?).to be false
    end
    
    it 'returns failure for non-existent consent' do
      result = service.revoke_consent('non_existent_type')
      
      expect(result.failure?).to be true
      expect(result.error).to eq('Consent not found')
    end
  end
  
  describe '#check_consent' do
    it 'returns true for granted consent' do
      service.grant_consent(
        'camera_access',
        granted_by: 'admin@example.com',
        ip_address: '127.0.0.1'
      )
      
      expect(service.check_consent('camera_access')).to be true
    end
    
    it 'returns false for non-existent consent' do
      expect(service.check_consent('camera_access')).to be false
    end
  end
  
  describe '#consent_status' do
    it 'returns status for all consent types' do
      statuses = service.consent_status
      
      expect(statuses).to be_an(Array)
      expect(statuses.length).to eq(DeviceConsent::CONSENT_TYPES.length)
      expect(statuses.first).to have_key(:type)
      expect(statuses.first).to have_key(:granted)
    end
  end
  
  describe '#export_consent_history' do
    it 'exports complete history' do
      service.grant_consent('device_monitoring', granted_by: 'admin', ip_address: '127.0.0.1')
      
      history = service.export_consent_history
      
      expect(history).to have_key(:device_id)
      expect(history).to have_key(:consents)
      expect(history).to have_key(:terms)
      expect(history).to have_key(:disclosures)
      expect(history).to have_key(:exported_at)
    end
  end
end

RSpec.describe ConsentEnforcement, type: :middleware do
  let(:app) { ->(env) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }
  let(:middleware) { ConsentEnforcement.new(app) }
  let(:device) { create(:apk_installation) }
  
  describe 'protected endpoints' do
    it 'blocks location endpoint without consent' do
      env = Rack::MockRequest.env_for("/apk_installations/#{device.id}/location")
      status, headers, body = middleware.call(env)
      
      expect(status).to eq(403)
      response = JSON.parse(body.first)
      expect(response['error']).to include('location_tracking')
    end
    
    it 'allows location endpoint with consent' do
      consent = device.device_consents.create!(
        consent_type: 'location_tracking',
        granted: true,
        granted_at: Time.current
      )
      
      env = Rack::MockRequest.env_for("/apk_installations/#{device.id}/location")
      status, _, _ = middleware.call(env)
      
      expect(status).to eq(200)
    end
    
    it 'does not block unprotected endpoints' do
      env = Rack::MockRequest.env_for("/apk_installations/#{device.id}/info")
      status, _, _ = middleware.call(env)
      
      expect(status).to eq(200)
    end
  end
end
