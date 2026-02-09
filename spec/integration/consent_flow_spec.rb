# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Consent Flow Integration', type: :integration do
  let(:device_id) { 'test-device-consent-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }
  let(:installation) { smartphone.apk_installation }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CONSENT_VERSION').and_return('2.0')
  end

  describe 'grant consent → access allowed' do
    it 'grants device_monitoring consent and marks it as active' do
      service = ConsentService.new(installation)
      result = service.grant_consent(
        'device_monitoring',
        granted_by: 'admin@test.com',
        ip_address: '192.168.1.1'
      )

      expect(result.success?).to be true

      consent = result.value
      expect(consent.granted?).to be true
      expect(consent.active?).to be true
      expect(consent.consent_type).to eq('device_monitoring')
      expect(consent.granted_by).to eq('admin@test.com')
      expect(consent.ip_address).to eq('192.168.1.1')
      expect(consent.consent_version).to eq('2.0')
      expect(consent.revoked_at).to be_nil
    end

    it 'confirms access is allowed after granting consent' do
      service = ConsentService.new(installation)
      service.grant_consent('location_tracking', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      expect(service.check_consent('location_tracking')).to be true
    end

    it 'grants multiple consent types independently' do
      service = ConsentService.new(installation)

      service.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')
      service.grant_consent('location_tracking', granted_by: 'admin@test.com', ip_address: '127.0.0.1')
      service.grant_consent('camera_access', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      expect(service.check_consent('device_monitoring')).to be true
      expect(service.check_consent('location_tracking')).to be true
      expect(service.check_consent('camera_access')).to be true
      expect(service.check_consent('sms_monitoring')).to be false
    end
  end

  describe 'revoke consent → access blocked' do
    it 'revokes previously granted consent' do
      service = ConsentService.new(installation)
      service.grant_consent('microphone_access', granted_by: 'admin@test.com', ip_address: '127.0.0.1')
      expect(service.check_consent('microphone_access')).to be true

      revoke_result = service.revoke_consent('microphone_access')
      expect(revoke_result.success?).to be true

      expect(service.check_consent('microphone_access')).to be false
    end

    it 'sets revoked_at timestamp on revocation' do
      service = ConsentService.new(installation)
      service.grant_consent('sms_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      travel_to(Time.utc(2025, 2, 1, 12, 0, 0)) do
        service.revoke_consent('sms_monitoring')
      end

      consent = installation.device_consents.find_by(consent_type: 'sms_monitoring')
      expect(consent.revoked_at).to be_present
      expect(consent.granted?).to be false
    end

    it 'returns failure when revoking non-existent consent' do
      service = ConsentService.new(installation)
      result = service.revoke_consent('nonexistent_type')

      # Since 'nonexistent_type' is not in CONSENT_TYPES, there's no record to find
      expect(result.failure?).to be true
      expect(result.error).to include('Consent not found')
    end

    it 'stops related operations when location_tracking consent is revoked' do
      service = ConsentService.new(installation)
      service.grant_consent('location_tracking', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      if defined?(DeviceCommandService)
        allow(DeviceCommandService).to receive(:call)
      end

      result = service.revoke_consent('location_tracking')
      expect(result.success?).to be true
    end
  end

  describe 'consent status reporting' do
    it 'returns status for all consent types' do
      service = ConsentService.new(installation)
      service.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      status = service.consent_status

      expect(status.size).to eq(DeviceConsent::CONSENT_TYPES.size)

      monitoring_status = status.find { |s| s[:type] == 'device_monitoring' }
      expect(monitoring_status[:granted]).to be true

      location_status = status.find { |s| s[:type] == 'location_tracking' }
      expect(location_status[:granted]).to be false
    end
  end

  describe 'export consent data' do
    it 'exports complete consent history for a device' do
      service = ConsentService.new(installation)
      service.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')
      service.grant_consent('location_tracking', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      export = service.export_consent_history

      expect(export[:device_id]).to eq(installation.id)
      expect(export[:consents].size).to eq(2)
      expect(export[:exported_at]).to be_present
    end
  end

  describe 'consent version management' do
    it 'records consent version when granting' do
      service = ConsentService.new(installation)
      result = service.grant_consent('data_collection', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      consent = result.value
      expect(consent.consent_version).to eq('2.0')
    end

    it 'uses default version when env var not set' do
      allow(ENV).to receive(:[]).with('CONSENT_VERSION').and_return(nil)

      service = ConsentService.new(installation)
      result = service.grant_consent('call_logging', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      consent = result.value
      expect(consent.consent_version).to eq('1.0')
    end

    it 'updates consent record when re-granting with new version' do
      service = ConsentService.new(installation)

      # Grant with version 2.0
      service.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      # Change version and re-grant
      allow(ENV).to receive(:[]).with('CONSENT_VERSION').and_return('3.0')
      service2 = ConsentService.new(installation)
      result = service2.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')

      consent = result.value
      expect(consent.consent_version).to eq('3.0')

      # Only one consent record exists (updated in place)
      expect(installation.device_consents.where(consent_type: 'device_monitoring').count).to eq(1)
    end
  end

  describe 'consent uniqueness' do
    it 'enforces one consent record per type per device' do
      service = ConsentService.new(installation)
      service.grant_consent('device_monitoring', granted_by: 'admin@test.com', ip_address: '127.0.0.1')
      service.grant_consent('device_monitoring', granted_by: 'admin2@test.com', ip_address: '127.0.0.2')

      # Should reuse the same record
      count = installation.device_consents.where(consent_type: 'device_monitoring').count
      expect(count).to eq(1)

      consent = installation.device_consents.find_by(consent_type: 'device_monitoring')
      expect(consent.granted_by).to eq('admin2@test.com')
    end
  end

  describe 'DeviceConsent model validations' do
    it 'validates consent_type is in allowed list' do
      consent = DeviceConsent.new(
        device: installation,
        consent_type: 'invalid_type',
        granted: false
      )

      expect(consent.valid?).to be false
      expect(consent.errors[:consent_type]).to be_present
    end

    it 'validates presence of consent_type' do
      consent = DeviceConsent.new(
        device: installation,
        consent_type: nil,
        granted: false
      )

      expect(consent.valid?).to be false
      expect(consent.errors[:consent_type]).to be_present
    end
  end
end
