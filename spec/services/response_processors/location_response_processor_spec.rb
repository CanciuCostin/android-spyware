require 'rails_helper'

RSpec.describe LocationResponseProcessor do
  let(:smartphone) { create(:smartphone, device_id: 'device-123') }
  let(:pending_command) { create(:pending_command, smartphone: smartphone, command: 'get_location') }
  
  describe '#process' do
    context 'with valid location data' do
      let(:response) do
        {
          'location' => {
            'latitude' => 37.7749,
            'longitude' => -122.4194,
            'provider' => 'gps',
            'accuracy' => 10.5,
            'speed' => 5.0,
            'bearing' => 90.0,
            'altitude' => 100.0,
            'timestamp' => Time.current.to_i
          }
        }
      end
      
      it 'creates a GeoLocation record' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(GeoLocation, :count).by(1)
        
        geo_location = GeoLocation.last
        expect(geo_location.smartphone).to eq(smartphone)
        expect(geo_location.latitude).to eq(37.7749)
        expect(geo_location.longitude).to eq(-122.4194)
      end
      
      it 'marks pending command as completed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('completed')
        expect(pending_command.response_data).to eq(response)
      end
      
      context 'when SAVE_LOCATION_FILES is enabled' do
        before do
          allow(ENV).to receive(:[]).with('SAVE_LOCATION_FILES').and_return('true')
          allow(ENV).to receive(:[]).and_call_original
        end
        
        after do
          # Cleanup test files
          FileUtils.rm_rf(Rails.root.join('files', 'dumps', 'locations'))
        end
        
        it 'saves location data to file' do
          described_class.new(pending_command, response).process
          
          location_files = Dir.glob(Rails.root.join('files', 'dumps', 'locations', 'location_*.txt'))
          expect(location_files).not_to be_empty
          
          file_content = File.read(location_files.first)
          expect(file_content).to include('Latitude: 37.7749')
          expect(file_content).to include('Longitude: -122.4194')
          expect(file_content).to include('Provider: gps')
          expect(file_content).to include('Accuracy: 10.5m')
        end
      end
    end
    
    context 'with missing latitude' do
      let(:response) do
        {
          'location' => {
            'longitude' => -122.4194,
            'provider' => 'gps'
          }
        }
      end
      
      it 'does not create a GeoLocation record' do
        expect {
          described_class.new(pending_command, response).process
        }.not_to change(GeoLocation, :count)
      end
      
      it 'marks pending command as failed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('missing latitude or longitude')
      end
    end
    
    context 'with missing longitude' do
      let(:response) do
        {
          'location' => {
            'latitude' => 37.7749,
            'provider' => 'network'
          }
        }
      end
      
      it 'does not create a GeoLocation record' do
        expect {
          described_class.new(pending_command, response).process
        }.not_to change(GeoLocation, :count)
      end
      
      it 'marks pending command as failed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('missing latitude or longitude')
      end
    end
    
    context 'with empty location object' do
      let(:response) { { 'location' => {} } }
      
      it 'marks pending command as failed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('Invalid location data')
      end
    end
    
    context 'with missing location key' do
      let(:response) { {} }
      
      it 'marks pending command as failed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('Invalid location data')
      end
    end
    
    context 'when GeoLocation creation fails' do
      let(:response) do
        {
          'location' => {
            'latitude' => 37.7749,
            'longitude' => -122.4194
          }
        }
      end
      
      before do
        allow(GeoLocation).to receive(:create!).and_raise(StandardError, 'Database error')
      end
      
      it 'marks pending command as failed' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('Failed to process location')
        expect(pending_command.response_data['error']).to include('Database error')
      end
    end
    
    context 'with invalid latitude values' do
      let(:response) do
        {
          'location' => {
            'latitude' => 200.0, # Invalid: out of range
            'longitude' => -122.4194
          }
        }
      end
      
      it 'handles validation errors gracefully' do
        described_class.new(pending_command, response).process
        
        expect(pending_command.reload.status).to eq('failed')
        expect(pending_command.response_data['error']).to include('Failed to process location')
      end
    end
    
    context 'with edge case coordinates' do
      let(:response) do
        {
          'location' => {
            'latitude' => 0.0,
            'longitude' => 0.0
          }
        }
      end
      
      it 'creates a GeoLocation record' do
        expect {
          described_class.new(pending_command, response).process
        }.to change(GeoLocation, :count).by(1)
        
        geo_location = GeoLocation.last
        expect(geo_location.latitude).to eq(0.0)
        expect(geo_location.longitude).to eq(0.0)
      end
    end
  end
end
