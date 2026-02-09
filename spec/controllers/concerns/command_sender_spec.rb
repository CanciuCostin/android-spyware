require 'rails_helper'

RSpec.describe CommandSender do
  let(:test_class) do
    Class.new do
      include CommandSender
    end
  end
  let(:subject) { test_class.new }
  let(:smartphone) { create(:smartphone, device_id: 'device-123') }
  
  describe '#send_command_async' do
    context 'with valid command and params' do
      it 'creates a PendingCommand record' do
        expect {
          subject.send_command_async(smartphone, 'get_contacts')
        }.to change(PendingCommand, :count).by(1)
        
        pending_command = PendingCommand.last
        expect(pending_command.smartphone).to eq(smartphone)
        expect(pending_command.command).to eq('get_contacts')
        expect(pending_command.status).to eq('pending')
        expect(pending_command.request_id).to be_present
      end
      
      it 'broadcasts command to ActionCable' do
        expect(ActionCable.server).to receive(:broadcast).with(
          "commands_device-123",
          hash_including(
            command: 'get_contacts',
            request_id: kind_of(String)
          )
        )
        
        subject.send_command_async(smartphone, 'get_contacts')
      end
      
      it 'returns the pending command' do
        pending_command = subject.send_command_async(smartphone, 'get_device_info')
        
        expect(pending_command).to be_a(PendingCommand)
        expect(pending_command.persisted?).to be true
      end
    end
    
    context 'with command parameters' do
      it 'includes sanitized params in pending command and broadcast' do
        params = { phone_number: '+1234567890', message_body: 'Test message' }
        
        expect(ActionCable.server).to receive(:broadcast).with(
          "commands_device-123",
          hash_including(
            command: 'send_sms',
            params: hash_including(phone_number: '+1234567890', message_body: 'Test message')
          )
        )
        
        pending_command = subject.send_command_async(smartphone, 'send_sms', params)
        expect(pending_command.params).to include('phone_number' => '+1234567890')
      end
    end
    
    context 'with invalid command' do
      it 'raises ArgumentError for non-whitelisted command' do
        expect {
          subject.send_command_async(smartphone, 'invalid_command')
        }.to raise_error(ArgumentError, /Invalid command/)
      end
      
      it 'does not create PendingCommand record' do
        expect {
          subject.send_command_async(smartphone, 'invalid_command') rescue nil
        }.not_to change(PendingCommand, :count)
      end
    end
    
    context 'when device_id is missing' do
      let(:smartphone_without_device_id) { create(:smartphone, device_id: nil) }
      
      it 'raises an error' do
        expect {
          subject.send_command_async(smartphone_without_device_id, 'get_contacts')
        }.to raise_error(/Device ID not set/)
      end
    end
    
    context 'parameter sanitization' do
      describe 'send_sms command' do
        it 'sanitizes phone number to allowed characters' do
          params = { phone_number: '+1(234)567-8900 ext 123', message_body: 'Test' }
          pending_command = subject.send_command_async(smartphone, 'send_sms', params)
          
          # Should keep: digits, +, -, (), spaces
          expect(pending_command.params['phone_number']).to eq('+1(234)567-8900 123')
        end
        
        it 'limits phone number length to 20 characters' do
          params = { phone_number: '1' * 50, message_body: 'Test' }
          pending_command = subject.send_command_async(smartphone, 'send_sms', params)
          
          expect(pending_command.params['phone_number'].length).to eq(20)
        end
        
        it 'limits message body to 1000 characters' do
          params = { phone_number: '+1234567890', message_body: 'a' * 2000 }
          pending_command = subject.send_command_async(smartphone, 'send_sms', params)
          
          expect(pending_command.params['message_body'].length).to eq(1000)
        end
        
        it 'strips whitespace from message body' do
          params = { phone_number: '+1234567890', message_body: "  Test message  \n" }
          pending_command = subject.send_command_async(smartphone, 'send_sms', params)
          
          expect(pending_command.params['message_body']).to eq('Test message')
        end
      end
      
      describe 'uninstall_app/launch_app commands' do
        it 'sanitizes package name to allowed characters' do
          params = { package_name: 'com.example.app!@#$%^&*' }
          pending_command = subject.send_command_async(smartphone, 'uninstall_app', params)
          
          expect(pending_command.params['package_name']).to eq('com.example.app')
        end
        
        it 'limits package name length to 255 characters' do
          params = { package_name: 'com.' + ('a' * 500) }
          pending_command = subject.send_command_async(smartphone, 'launch_app', params)
          
          expect(pending_command.params['package_name'].length).to eq(255)
        end
      end
      
      describe 'start_camera command' do
        it 'sanitizes camera_id to digits only' do
          params = { camera_id: '1abc' }
          pending_command = subject.send_command_async(smartphone, 'start_camera', params)
          
          expect(pending_command.params['camera_id']).to eq('1')
        end
        
        it 'limits camera_id to 2 digits' do
          params = { camera_id: '12345' }
          pending_command = subject.send_command_async(smartphone, 'start_camera', params)
          
          expect(pending_command.params['camera_id']).to eq('12')
        end
      end
      
      describe 'set_audio_mode command' do
        it 'accepts valid audio modes' do
          %w[normal vibrate silent].each do |mode|
            params = { mode: mode }
            pending_command = subject.send_command_async(smartphone, 'set_audio_mode', params)
            
            expect(pending_command.params['mode']).to eq(mode)
          end
        end
        
        it 'defaults to normal for invalid mode' do
          params = { mode: 'invalid_mode' }
          pending_command = subject.send_command_async(smartphone, 'set_audio_mode', params)
          
          expect(pending_command.params['mode']).to eq('normal')
        end
      end
      
      describe 'install_apk command' do
        it 'accepts valid HTTP URLs' do
          params = { apk_path: 'http://example.com/app.apk' }
          pending_command = subject.send_command_async(smartphone, 'install_apk', params)
          
          expect(pending_command.params['apk_path']).to eq('http://example.com/app.apk')
        end
        
        it 'accepts valid HTTPS URLs' do
          params = { apk_path: 'https://example.com/app.apk' }
          pending_command = subject.send_command_async(smartphone, 'install_apk', params)
          
          expect(pending_command.params['apk_path']).to eq('https://example.com/app.apk')
        end
        
        it 'rejects javascript: URLs' do
          params = { apk_path: 'javascript:alert(1)' }
          pending_command = subject.send_command_async(smartphone, 'install_apk', params)
          
          expect(pending_command.params['apk_path']).to be_nil
        end
      end
    end
  end
  
  describe '#wait_for_response' do
    let(:pending_command) { create(:pending_command, smartphone: smartphone, status: :pending) }
    
    context 'when command completes successfully' do
      it 'returns the completed command' do
        allow(pending_command).to receive(:reload).and_return(pending_command)
        allow(pending_command).to receive(:completed?).and_return(true)
        
        result = subject.wait_for_response(pending_command, timeout: 5.seconds)
        
        expect(result).to eq(pending_command)
      end
    end
    
    context 'when command fails' do
      it 'returns the failed command' do
        allow(pending_command).to receive(:reload).and_return(pending_command)
        allow(pending_command).to receive(:completed?).and_return(false)
        allow(pending_command).to receive(:failed?).and_return(true)
        
        result = subject.wait_for_response(pending_command, timeout: 5.seconds)
        
        expect(result).to eq(pending_command)
      end
    end
    
    context 'when timeout occurs' do
      it 'marks command as failed with timeout message' do
        result = subject.wait_for_response(pending_command, timeout: 0.1.seconds)
        
        expect(result.reload.status).to eq('failed')
        expect(result.response_data['error']).to include('Timeout')
      end
    end
    
    context 'when command is already timed out' do
      before do
        allow(pending_command).to receive(:reload).and_return(pending_command)
        allow(pending_command).to receive(:completed?).and_return(false)
        allow(pending_command).to receive(:failed?).and_return(false)
        allow(pending_command).to receive(:timeout?).and_return(true)
      end
      
      it 'returns the timed out command' do
        result = subject.wait_for_response(pending_command, timeout: 5.seconds)
        
        expect(result).to eq(pending_command)
      end
    end
  end
  
  describe '#send_command_and_wait' do
    it 'sends command and waits for response' do
      expect(subject).to receive(:send_command_async).with(smartphone, 'get_contacts', {}).and_call_original
      expect(subject).to receive(:wait_for_response).and_call_original
      
      result = subject.send_command_and_wait(smartphone, 'get_contacts', {}, timeout: 0.1.seconds)
      
      expect(result).to be_a(PendingCommand)
    end
    
    it 'passes custom timeout to wait_for_response' do
      pending_command = double('PendingCommand')
      allow(subject).to receive(:send_command_async).and_return(pending_command)
      expect(subject).to receive(:wait_for_response).with(pending_command, timeout: 60.seconds)
      
      subject.send_command_and_wait(smartphone, 'get_device_info', {}, timeout: 60.seconds)
    end
  end
  
  describe 'ALLOWED_COMMANDS constant' do
    it 'includes essential commands' do
      expect(CommandSender::ALLOWED_COMMANDS).to include(
        'get_contacts',
        'get_device_info',
        'take_picture',
        'get_location',
        'send_sms'
      )
    end
    
    it 'is frozen to prevent modification' do
      expect(CommandSender::ALLOWED_COMMANDS).to be_frozen
    end
  end
end
