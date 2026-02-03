# frozen_string_literal: true

# Centralized credentials management - Never hardcode credentials!
# SonarQube Rule: S2068 - Credentials should not be hard-coded
class CredentialsService
  class << self
    def msf_user
      ENV.fetch('MSF_RPC_USER', 'msf_user')
    end

    def msf_password
      ENV.fetch('MSF_RPC_PASSWORD') do
        Rails.logger.warn('MSF_RPC_PASSWORD not set! Using insecure default.')
        'change_me_in_production'
      end
    end

    def msf_host
      ENV.fetch('RAILS_HOST', 'metasploit')
    end

    def msf_port
      ENV.fetch('MSF_RPC_PORT', '3333').to_i
    end

    def adb_host
      ENV.fetch('ADB_HOST', 'localhost')
    end

    def msf_options
      {
        host: msf_host,
        port: msf_port,
        uri: '/api/',
        ssl: true
      }
    end
  end
end
