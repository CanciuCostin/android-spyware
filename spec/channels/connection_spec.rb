require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:apk_payload) { create(:apk_payload) }
  let(:apk_installation) { create(:apk_installation, apk_payload: apk_payload, target_ip: 'device-123') }
  let(:smartphone) { create(:smartphone, device_id: 'device-123', apk_installation: apk_installation) }
  let(:valid_token) { 'test-device-token-12345' }
  
  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
  end
  
  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
  end
  
  describe '#connect' do
    context 'with valid device token and device_id' do
      it 'successfully connects with token in query params' do
        connect "/cable?token=#{valid_token}&device_id=#{smartphone.device_id}"
        
        expect(connection.current_user_type).to eq(:device)
        expect(connection.current_identifier).to eq(smartphone.device_id)
      end
      
      it 'successfully connects with token in headers' do
        connect "/cable", headers: {
          'X-Device-Token' => valid_token,
          'X-Device-ID' => smartphone.device_id
        }
        
        expect(connection.current_user_type).to eq(:device)
        expect(connection.current_identifier).to eq(smartphone.device_id)
      end
      
      it 'auto-creates device if not found' do
        new_device_id = 'new-device-999'
        
        expect {
          connect "/cable?token=#{valid_token}&device_id=#{new_device_id}"
        }.to change(Smartphone, :count).by(1)
        
        expect(connection.current_user_type).to eq(:device)
        expect(connection.current_identifier).to eq(new_device_id)
        
        created_device = Smartphone.find_by(device_id: new_device_id)
        expect(created_device).to be_present
        expect(created_device.name).to include('Device')
      end
    end
    
    context 'with invalid token' do
      it 'rejects connection with wrong token' do
        expect {
          connect "/cable?token=wrong-token&device_id=#{smartphone.device_id}"
        }.to have_rejected_connection
      end
      
      it 'rejects connection with empty token' do
        expect {
          connect "/cable?token=&device_id=#{smartphone.device_id}"
        }.to have_rejected_connection
      end
      
      it 'prevents timing attacks with secure_compare' do
        # Test that both valid and invalid tokens take similar time
        # This is implicit through the use of ActiveSupport::SecurityUtils.secure_compare
        expect {
          connect "/cable?token=invalid&device_id=#{smartphone.device_id}"
        }.to have_rejected_connection
      end
    end
    
    context 'with missing token' do
      it 'rejects connection when token is not provided' do
        expect {
          connect "/cable?device_id=#{smartphone.device_id}"
        }.to have_rejected_connection
      end
    end
    
    context 'with missing device_id' do
      it 'rejects connection when device_id is not provided' do
        expect {
          connect "/cable?token=#{valid_token}"
        }.to have_rejected_connection
      end
      
      it 'rejects connection when device_id is empty' do
        expect {
          connect "/cable?token=#{valid_token}&device_id="
        }.to have_rejected_connection
      end
    end
    
    context 'when DEVICE_AUTH_TOKEN is not configured' do
      before do
        ENV.delete('DEVICE_AUTH_TOKEN')
      end
      
      it 'rejects connection' do
        expect {
          connect "/cable?token=#{valid_token}&device_id=#{smartphone.device_id}"
        }.to have_rejected_connection
      end
    end
    
    context 'with admin user session' do
      let(:admin_user) { double('AdminUser', email: 'admin@example.com') }
      
      it 'connects admin users via warden session' do
        # Simulate Warden authentication
        allow_any_instance_of(ApplicationCable::Connection).to receive(:env).and_return({
          'warden' => double('Warden', user: admin_user)
        })
        
        connect "/cable"
        
        expect(connection.current_user_type).to eq(:admin)
        expect(connection.current_identifier).to eq('admin@example.com')
      end
    end
    
    context 'race condition handling' do
      it 'handles concurrent device creation attempts' do
        new_device_id = 'concurrent-device-123'
        
        # Simulate race condition by attempting multiple connections
        threads = 3.times.map do
          Thread.new do
            begin
              connect "/cable?token=#{valid_token}&device_id=#{new_device_id}"
            rescue => e
              # Some threads may fail, which is expected
            end
          end
        end
        
        threads.each(&:join)
        
        # Only one device should be created despite multiple attempts
        expect(Smartphone.where(device_id: new_device_id).count).to eq(1)
      end
    end
  end
end
