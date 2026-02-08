require 'rails_helper'

RSpec.describe DeviceInfoResponseProcessor do
  let(:smartphone) { create(:smartphone, device_id: 'device-123', name: 'Old Phone', operating_system: 'Android 9') }
  let(:pending_command) { create(:pending_command, smartphone: smartphone, command: 'get_device_info') }
  
  describe '#process' do
    context 'with complete device info' do
      let(:response) do
        {
          'device_model' => 'Samsung Galaxy S21',
          'android_version' => '12',
          'battery_level' => 85,
          'is_rooted' => true
        }
      end
      
      it 'updates smartphone with all device information' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('Samsung Galaxy S21')
        expect(smartphone.operating_system).to eq('Android 12')
        expect(smartphone.is_rooted).to eq(true)
      end
      
      it 'marks pending command as completed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('completed')
        expect(pending_command.response_data).to eq(response)
      end
    end
    
    context 'with model key instead of device_model' do
      let(:response) do
        {
          'model' => 'Google Pixel 6',
          'android_version' => '13'
        }
      end
      
      it 'updates smartphone name from model key' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('Google Pixel 6')
        expect(smartphone.operating_system).to eq('Android 13')
      end
    end
    
    context 'with partial device info' do
      let(:response) do
        {
          'device_model' => 'OnePlus 9'
        }
      end
      
      it 'updates only provided fields' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('OnePlus 9')
        expect(smartphone.operating_system).to eq('Android 9') # Unchanged
        expect(smartphone.is_rooted).to eq(false) # Unchanged
      end
    end
    
    context 'with android_version only' do
      let(:response) do
        {
          'android_version' => '11'
        }
      end
      
      it 'updates only operating_system' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('Old Phone') # Unchanged
        expect(smartphone.operating_system).to eq('Android 11')
      end
    end
    
    context 'with is_rooted only' do
      let(:response) do
        {
          'is_rooted' => true
        }
      end
      
      it 'updates only is_rooted' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.is_rooted).to eq(true)
        expect(smartphone.name).to eq('Old Phone') # Unchanged
      end
    end
    
    context 'with is_rooted false' do
      let(:smartphone) { create(:smartphone, device_id: 'device-123', is_rooted: true) }
      let(:response) do
        {
          'is_rooted' => false
        }
      end
      
      it 'updates is_rooted to false' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.is_rooted).to eq(false)
      end
    end
    
    context 'with empty response' do
      let(:response) { {} }
      
      it 'does not update any fields' do
        original_name = smartphone.name
        original_os = smartphone.operating_system
        original_rooted = smartphone.is_rooted
        
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq(original_name)
        expect(smartphone.operating_system).to eq(original_os)
        expect(smartphone.is_rooted).to eq(original_rooted)
      end
      
      it 'still marks pending command as completed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('completed')
      end
    end
    
    context 'with blank string values' do
      let(:response) do
        {
          'device_model' => '',
          'android_version' => ''
        }
      end
      
      it 'does not update fields with blank values' do
        original_name = smartphone.name
        original_os = smartphone.operating_system
        
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq(original_name)
        expect(smartphone.operating_system).to eq(original_os)
      end
    end
    
    context 'with nil values' do
      let(:response) do
        {
          'device_model' => nil,
          'android_version' => nil,
          'is_rooted' => nil
        }
      end
      
      it 'does not update fields with nil values' do
        original_name = smartphone.name
        original_os = smartphone.operating_system
        original_rooted = smartphone.is_rooted
        
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq(original_name)
        expect(smartphone.operating_system).to eq(original_os)
        expect(smartphone.is_rooted).to eq(original_rooted)
      end
    end
    
    context 'with extra fields in response' do
      let(:response) do
        {
          'device_model' => 'Xiaomi Mi 11',
          'android_version' => '12',
          'battery_level' => 75,
          'storage_total' => '128GB',
          'ram_total' => '8GB',
          'unknown_field' => 'value'
        }
      end
      
      it 'updates known fields and ignores unknown fields' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('Xiaomi Mi 11')
        expect(smartphone.operating_system).to eq('Android 12')
      end
    end
    
    context 'when smartphone update fails' do
      let(:response) do
        {
          'device_model' => 'Test Phone'
        }
      end
      
      before do
        allow(smartphone).to receive(:update).and_raise(ActiveRecord::RecordInvalid)
      end
      
      it 'raises an error' do
        expect {
          described_class.new(pending_command, response).process
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
    
    context 'with special characters in device model' do
      let(:response) do
        {
          'device_model' => 'Samsung Galaxy S21 5G (2021)',
          'android_version' => '12.0.1'
        }
      end
      
      it 'preserves special characters' do
        described_class.new(pending_command, response).process
        
        smartphone.reload
        expect(smartphone.name).to eq('Samsung Galaxy S21 5G (2021)')
        expect(smartphone.operating_system).to eq('Android 12.0.1')
      end
    end
  end
end
