require 'rails_helper'

RSpec.describe DeviceCommandService do
  let(:smartphone) { create(:smartphone, device_id: 'device-123') }
  
  describe '#call' do
    context 'with valid smartphone and command' do
      it 'returns success with pending command' do
        service = described_class.new(smartphone, 'get_contacts')
        result = service.call
        
        expect(result.success?).to be true
        expect(result.value).to be_a(PendingCommand)
        expect(result.value.command).to eq('get_contacts')
      end
      
      it 'creates a pending command' do
        service = described_class.new(smartphone, 'get_device_info')
        
        expect {
          service.call
        }.to change(PendingCommand, :count).by(1)
      end
      
      it 'broadcasts command to device' do
        service = described_class.new(smartphone, 'take_picture')
        
        expect(ActionCable.server).to receive(:broadcast).with(
          "commands_device-123",
          hash_including(command: 'take_picture')
        )
        
        service.call
      end
    end
    
    context 'with command parameters' do
      it 'passes parameters to send_command_async' do
        params = { phone_number: '+1234567890', message_body: 'Test' }
        service = described_class.new(smartphone, 'send_sms', params)
        
        result = service.call
        
        expect(result.success?).to be true
        expect(result.value.params).to include('phone_number' => '+1234567890')
      end
    end
    
    context 'without smartphone' do
      it 'returns failure' do
        service = described_class.new(nil, 'get_contacts')
        result = service.call
        
        expect(result.success?).to be false
        expect(result.error).to eq('Smartphone is required')
      end
      
      it 'does not create a pending command' do
        service = described_class.new(nil, 'get_contacts')
        
        expect {
          service.call
        }.not_to change(PendingCommand, :count)
      end
    end
    
    context 'without command' do
      it 'returns failure' do
        service = described_class.new(smartphone, nil)
        result = service.call
        
        expect(result.success?).to be false
        expect(result.error).to eq('Command is required')
      end
    end
    
    context 'with invalid device' do
      let(:smartphone_without_device_id) { create(:smartphone, device_id: nil) }
      
      it 'returns failure' do
        service = described_class.new(smartphone_without_device_id, 'get_contacts')
        result = service.call
        
        expect(result.success?).to be false
        expect(result.error).to include('Device not connected')
      end
    end
    
    context 'with invalid command' do
      it 'returns failure for non-whitelisted command' do
        service = described_class.new(smartphone, 'invalid_command')
        result = service.call
        
        expect(result.success?).to be false
        expect(result.error).to include('Invalid command')
      end
    end
    
    context 'when send_command_async raises error' do
      before do
        allow_any_instance_of(described_class).to receive(:send_command_async).and_raise(StandardError, 'Network error')
      end
      
      it 'returns failure with error message' do
        service = described_class.new(smartphone, 'get_contacts')
        result = service.call
        
        expect(result.success?).to be false
        expect(result.error).to eq('Network error')
      end
      
      it 'logs the error' do
        service = described_class.new(smartphone, 'get_contacts')
        
        expect(Rails.logger).to receive(:error).with(/Command failed/)
        
        service.call
      end
    end
  end
  
  describe '#queue_command (legacy)' do
    it 'sends command asynchronously' do
      service = described_class.new(smartphone)
      
      pending_command = service.queue_command('get_contacts')
      
      expect(pending_command).to be_a(PendingCommand)
      expect(pending_command.status).to eq('pending')
    end
    
    it 'raises error without smartphone' do
      service = described_class.new(nil)
      
      expect {
        service.queue_command('get_contacts')
      }.to raise_error(ArgumentError, /Smartphone is required/)
    end
    
    it 'accepts command parameters' do
      service = described_class.new(smartphone)
      params = { package_name: 'com.example.app' }
      
      pending_command = service.queue_command('launch_app', params)
      
      expect(pending_command.params).to include('package_name' => 'com.example.app')
    end
  end
  
  describe '#wait_for_command (legacy)' do
    it 'sends command and waits for response' do
      service = described_class.new(smartphone)
      
      pending_command = service.wait_for_command('get_device_info', {}, timeout: 0.1.seconds)
      
      expect(pending_command).to be_a(PendingCommand)
    end
    
    it 'raises error without smartphone' do
      service = described_class.new(nil)
      
      expect {
        service.wait_for_command('get_contacts')
      }.to raise_error(ArgumentError, /Smartphone is required/)
    end
    
    it 'respects custom timeout' do
      service = described_class.new(smartphone)
      
      pending_command = service.wait_for_command('get_contacts', {}, timeout: 1.seconds)
      
      # Should timeout and be marked as failed
      expect(pending_command.reload.status).to eq('failed')
    end
  end
  
  describe '.devices_snapshot' do
    let!(:device1) { create(:smartphone, name: 'Phone 1', device_id: 'device-1') }
    let!(:device2) { create(:smartphone, name: 'Phone 2', device_id: 'device-2') }
    let!(:command1) { create(:pending_command, smartphone: device1, command: 'get_contacts', status: :completed) }
    
    it 'returns snapshot of devices with their status' do
      snapshot = described_class.devices_snapshot(limit: 20)
      
      expect(snapshot).to be_an(Array)
      expect(snapshot.length).to eq(2)
    end
    
    it 'includes device information' do
      snapshot = described_class.devices_snapshot
      
      device_info = snapshot.find { |d| d[:id] == device1.id }
      expect(device_info).to include(
        name: 'Phone 1',
        device_id: 'device-1',
        operating_system: kind_of(String),
        status: 'completed'
      )
    end
    
    it 'includes pending command count' do
      create(:pending_command, smartphone: device1, status: :pending)
      create(:pending_command, smartphone: device1, status: :pending)
      
      snapshot = described_class.devices_snapshot
      
      device_info = snapshot.find { |d| d[:id] == device1.id }
      expect(device_info[:pending]).to be >= 2
    end
    
    it 'includes last command summary' do
      snapshot = described_class.devices_snapshot
      
      device_info = snapshot.find { |d| d[:id] == device1.id }
      expect(device_info[:last_command]).to include(
        command: 'get_contacts',
        status: 'completed'
      )
    end
    
    it 'handles devices with no commands' do
      snapshot = described_class.devices_snapshot
      
      device_info = snapshot.find { |d| d[:id] == device2.id }
      expect(device_info[:status]).to eq('idle')
      expect(device_info[:last_command]).to be_nil
    end
    
    it 'respects limit parameter' do
      create_list(:smartphone, 25)
      
      snapshot = described_class.devices_snapshot(limit: 10)
      
      expect(snapshot.length).to eq(10)
    end
    
    it 'orders by updated_at descending' do
      device2.touch
      
      snapshot = described_class.devices_snapshot
      
      expect(snapshot.first[:id]).to eq(device2.id)
    end
  end
  
  describe '.command_queue' do
    let!(:smartphone) { create(:smartphone, device_id: 'device-123') }
    let!(:command1) { create(:pending_command, smartphone: smartphone, command: 'get_contacts', status: :completed) }
    let!(:command2) { create(:pending_command, smartphone: smartphone, command: 'take_picture', status: :pending) }
    
    it 'returns list of pending commands' do
      queue = described_class.command_queue
      
      expect(queue).to be_an(Array)
      expect(queue.length).to eq(2)
    end
    
    it 'includes command details' do
      queue = described_class.command_queue
      
      command_info = queue.find { |c| c[:request_id] == command1.request_id }
      expect(command_info).to include(
        command: 'get_contacts',
        status: 'completed',
        smartphone_id: smartphone.id,
        device_id: 'device-123'
      )
    end
    
    it 'orders by created_at descending' do
      queue = described_class.command_queue
      
      expect(queue.first[:request_id]).to eq(command2.request_id)
    end
    
    it 'respects limit parameter' do
      create_list(:pending_command, 35, smartphone: smartphone)
      
      queue = described_class.command_queue(limit: 20)
      
      expect(queue.length).to eq(20)
    end
  end
  
  describe '.webrtc_status' do
    let!(:smartphone) { create(:smartphone, device_id: 'device-123') }
    let!(:start_camera) { create(:pending_command, smartphone: smartphone, command: 'start_camera', status: :completed) }
    let!(:stop_camera) { create(:pending_command, smartphone: smartphone, command: 'stop_camera', status: :pending) }
    let!(:other_command) { create(:pending_command, smartphone: smartphone, command: 'get_contacts') }
    
    it 'returns only camera-related commands' do
      status = described_class.webrtc_status
      
      expect(status).to be_an(Array)
      expect(status.length).to eq(2)
      expect(status.map { |s| s[:command] }).to match_array(['start_camera', 'stop_camera'])
    end
    
    it 'includes command details' do
      status = described_class.webrtc_status
      
      command_info = status.find { |s| s[:request_id] == start_camera.request_id }
      expect(command_info).to include(
        command: 'start_camera',
        status: 'completed',
        device_id: 'device-123'
      )
    end
    
    it 'respects limit parameter' do
      create_list(:pending_command, 10, smartphone: smartphone, command: 'start_camera')
      
      status = described_class.webrtc_status(limit: 3)
      
      expect(status.length).to eq(3)
    end
  end
  
  describe '.upload_progress' do
    let(:uploads_dir) { Rails.root.join('tmp', 'uploads') }
    
    before do
      FileUtils.mkdir_p(uploads_dir)
    end
    
    after do
      FileUtils.rm_rf(uploads_dir)
    end
    
    context 'with existing uploads' do
      before do
        metadata = {
          upload_id: 'upload-123',
          filename: 'test.apk',
          total_chunks: 10,
          chunks_received: [1, 2, 3, 4, 5]
        }
        File.write(uploads_dir.join('upload-123.meta'), metadata.to_json)
      end
      
      it 'returns upload progress information' do
        progress = described_class.upload_progress
        
        expect(progress).to be_an(Array)
        expect(progress.length).to eq(1)
        
        upload_info = progress.first
        expect(upload_info).to include(
          upload_id: 'upload-123',
          filename: 'test.apk',
          total_chunks: 10,
          received_chunks: 5,
          progress: 50
        )
      end
    end
    
    context 'with multiple uploads' do
      before do
        2.times do |i|
          metadata = {
            upload_id: "upload-#{i}",
            filename: "file#{i}.apk",
            total_chunks: 20,
            chunks_received: Array.new(i * 5 + 5) { |n| n + 1 }
          }
          File.write(uploads_dir.join("upload-#{i}.meta"), metadata.to_json)
        end
      end
      
      it 'returns all upload progress' do
        progress = described_class.upload_progress
        
        expect(progress.length).to eq(2)
      end
    end
    
    context 'with malformed metadata' do
      before do
        File.write(uploads_dir.join('malformed.meta'), 'invalid json')
      end
      
      it 'handles gracefully with empty metadata' do
        progress = described_class.upload_progress
        
        upload_info = progress.first
        expect(upload_info[:progress]).to eq(0)
      end
    end
    
    context 'when uploads directory does not exist' do
      before do
        FileUtils.rm_rf(uploads_dir)
      end
      
      it 'returns empty array' do
        progress = described_class.upload_progress
        
        expect(progress).to eq([])
      end
    end
    
    context 'with zero total chunks' do
      before do
        metadata = {
          upload_id: 'upload-zero',
          filename: 'test.apk',
          total_chunks: 0,
          chunks_received: []
        }
        File.write(uploads_dir.join('upload-zero.meta'), metadata.to_json)
      end
      
      it 'calculates 0% progress' do
        progress = described_class.upload_progress
        
        expect(progress.first[:progress]).to eq(0)
      end
    end
  end
  
  describe 'private methods' do
    describe '#validate_device!' do
      it 'raises error when smartphone is nil' do
        service = described_class.new(nil, 'get_contacts')
        
        expect {
          service.send(:validate_device!)
        }.to raise_error(ArgumentError, /Device not found/)
      end
      
      it 'raises error when device_id is blank' do
        smartphone_without_id = create(:smartphone, device_id: '')
        service = described_class.new(smartphone_without_id, 'get_contacts')
        
        expect {
          service.send(:validate_device!)
        }.to raise_error(ArgumentError, /Device not connected/)
      end
      
      it 'does not raise error for valid device' do
        service = described_class.new(smartphone, 'get_contacts')
        
        expect {
          service.send(:validate_device!)
        }.not_to raise_error
      end
    end
    
    describe '#validate_command!' do
      it 'raises error for invalid command' do
        service = described_class.new(smartphone, 'invalid_cmd')
        
        expect {
          service.send(:validate_command!)
        }.to raise_error(ArgumentError, /Invalid command/)
      end
      
      it 'does not raise error for valid commands' do
        valid_commands = %w[take_screenshot location get_device_info]
        
        valid_commands.each do |cmd|
          service = described_class.new(smartphone, cmd)
          
          expect {
            service.send(:validate_command!)
          }.not_to raise_error
        end
      end
    end
  end
end
