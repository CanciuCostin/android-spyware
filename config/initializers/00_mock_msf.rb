if Gem.win_platform?
  module Msf
    module RPC
      class ServerException < StandardError; end

      class Client
        attr_accessor :token

        def initialize(opts = {})
          @token = "mock_token"
        end

        def login(user, pass)
          { "result" => "success", "token" => "mock_token" }
        end

        def call(method, *args)
          Rails.logger.info "MOCK MSF CALL: #{method} with args: #{args}"
          case method
          when "auth.login"
            { "result" => "success", "token" => "mock_temp_token" }
          when "session.list"
            { "1" => { "type" => "meterpreter", "tunnel_peer" => "192.168.1.25:5555" } }
          else
            { "result" => "success" }
          end
        end

        def logout
          true
        end
      end
    end
  end
end
