# frozen_string_literal: true

class FileBrowserChannel < ApplicationCable::Channel
  def subscribed
    device_id = params[:device_id]
    
    if device_id.present?
      stream_from "file_browser_#{device_id}"
      Rails.logger.info "[FileBrowserChannel] Subscribed to file_browser_#{device_id}"
    else
      Rails.logger.warn "[FileBrowserChannel] Subscription rejected: no device_id"
      reject
    end
  end

  def unsubscribed
    # Clean up when channel is unsubscribed
    Rails.logger.info "[FileBrowserChannel] Unsubscribed from file browser stream"
  end

  # Client can request file listing
  def list_files(data)
    device_id = params[:device_id]
    path = data['path'] || '/sdcard'
    
    smartphone = Smartphone.find_by(device_id: device_id)
    return unless smartphone
    
    # Send command to device
    pending_command = send_command_async(
      smartphone,
      'list_files',
      { path: path }
    )
    
    # Notify client that command was sent
    transmit({
      action: 'command_sent',
      request_id: pending_command.request_id,
      command: 'list_files',
      path: path
    })
  rescue StandardError => e
    Rails.logger.error "[FileBrowserChannel] Error listing files: #{e.message}"
    transmit({
      action: 'error',
      error: e.message
    })
  end

  # Client can request file download
  def download_file(data)
    device_id = params[:device_id]
    path = data['path']
    
    return unless path.present?
    
    smartphone = Smartphone.find_by(device_id: device_id)
    return unless smartphone
    
    pending_command = send_command_async(
      smartphone,
      'download_file',
      { path: path }
    )
    
    transmit({
      action: 'command_sent',
      request_id: pending_command.request_id,
      command: 'download_file',
      path: path
    })
  rescue StandardError => e
    Rails.logger.error "[FileBrowserChannel] Error downloading file: #{e.message}"
    transmit({
      action: 'error',
      error: e.message
    })
  end

  private

  def send_command_async(smartphone, command, params)
    request_id = SecureRandom.uuid
    
    pending_command = PendingCommand.create!(
      smartphone: smartphone,
      request_id: request_id,
      command: command,
      params: params,
      status: :pending
    )
    
    ActionCable.server.broadcast(
      "commands_#{smartphone.device_id}",
      {
        request_id: request_id,
        command: command,
        params: params
      }
    )
    
    pending_command
  end
end
