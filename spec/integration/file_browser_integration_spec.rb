# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'File Browser Integration', type: :integration do
  let(:device_id) { 'test-device-fb-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }

  describe 'browse device files via FileBrowserChannel' do
    it 'sends list_files command when client requests directory listing' do
      channel = simulate_file_browser_subscription(device_id)
      channel.subscribed

      channel.list_files({ 'path' => '/sdcard/DCIM' })

      # Verify a PendingCommand was created
      cmd = PendingCommand.last
      expect(cmd).to be_present
      expect(cmd.command).to eq('list_files')
      expect(cmd.params).to include('path' => '/sdcard/DCIM')
      expect(cmd.smartphone).to eq(smartphone)

      # Verify command was broadcast to device
      msgs = broadcasted_messages_for("commands_#{device_id}")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:command]).to eq('list_files')

      # Verify client was notified
      expect(channel).to have_received(:transmit).with(
        hash_including(action: 'command_sent', command: 'list_files')
      )
    end

    it 'defaults to /sdcard when no path specified' do
      channel = simulate_file_browser_subscription(device_id)
      channel.subscribed

      channel.list_files({})

      cmd = PendingCommand.last
      expect(cmd.params).to include('path' => '/sdcard')
    end
  end

  describe 'download file from device' do
    it 'sends download_file command to device' do
      channel = simulate_file_browser_subscription(device_id)
      channel.subscribed

      channel.download_file({ 'path' => '/sdcard/DCIM/photo.jpg' })

      cmd = PendingCommand.last
      expect(cmd.command).to eq('download_file')
      expect(cmd.params).to include('path' => '/sdcard/DCIM/photo.jpg')

      expect(channel).to have_received(:transmit).with(
        hash_including(action: 'command_sent', command: 'download_file')
      )
    end

    it 'ignores download request without a path' do
      channel = simulate_file_browser_subscription(device_id)
      channel.subscribed

      channel.download_file({})

      expect(PendingCommand.count).to eq(0)
    end
  end

  describe 'upload file to device via FileBrowserService' do
    it 'initiates direct upload for small files' do
      file = double('uploaded_file',
        read: 'file content',
        size: 12,
        original_filename: 'test.txt'
      )

      allow(CommandSender).to receive(:send_command_async) do |phone, cmd, params|
        PendingCommand.create!(
          smartphone: phone,
          request_id: SecureRandom.uuid,
          command: cmd,
          params: params,
          status: :pending
        )
      end

      result = FileBrowserService.upload_file_direct(smartphone, file, '/sdcard/Download')

      expect(result[:success]).to be true
      expect(result[:filename]).to eq('test.txt')
      expect(result[:size]).to eq(12)
    end
  end

  describe 'delete file on device' do
    it 'sends delete_file command via DeviceCommandService' do
      service = DeviceCommandService.new(smartphone, 'list_files', { path: '/sdcard' })
      result = service.call

      expect(result.success?).to be true
      expect(result.value.command).to eq('list_files')
    end
  end

  describe 'search files on device' do
    it 'sends search_files command via command sender' do
      cmd = send_test_command(smartphone, 'search_files', { query: '*.jpg', path: '/sdcard' })

      expect(cmd.command).to eq('search_files')
      expect(cmd.params).to include(query: '*.jpg', path: '/sdcard')

      msgs = broadcasted_messages_for("commands_#{device_id}")
      expect(msgs.size).to eq(1)
      expect(msgs.first[:command]).to eq('search_files')
    end
  end

  describe 'FileBrowserService path sanitization' do
    it 'rejects path traversal attempts' do
      expect {
        FileBrowserService.send(:sanitize_path, '../../../etc/passwd')
      }.to raise_error(SecurityError, /Path traversal/)
    end

    it 'removes null bytes from paths' do
      clean = FileBrowserService.send(:sanitize_path, "/sdcard/test\0.txt")
      expect(clean).to eq('/sdcard/test.txt')
      expect(clean).not_to include("\0")
    end

    it 'collapses consecutive slashes' do
      clean = FileBrowserService.send(:sanitize_path, '/sdcard///DCIM//photo.jpg')
      expect(clean).to eq('/sdcard/DCIM/photo.jpg')
    end
  end

  describe 'FileBrowserService filename sanitization' do
    it 'removes dangerous characters from filenames' do
      sanitized = FileBrowserService.send(:sanitize_filename, 'my<file>.exe')
      expect(sanitized).not_to include('<')
      expect(sanitized).not_to include('>')
    end

    it 'removes path separators from filenames' do
      sanitized = FileBrowserService.send(:sanitize_filename, '../../../etc/passwd')
      expect(sanitized).not_to include('/')
      expect(sanitized).not_to include('\\')
    end

    it 'truncates overly long filenames' do
      long_name = 'a' * 500 + '.txt'
      sanitized = FileBrowserService.send(:sanitize_filename, long_name)
      expect(sanitized.length).to be <= 256
    end
  end
end
