# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/jaeger'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry/instrumentation/rails'
require 'opentelemetry/instrumentation/http_client'

module SpywareTracing
  class << self
    attr_reader :tracer

    def initialize_tracing(environment: 'development')
      # Configure OpenTelemetry
      OpenTelemetry::SDK.configure do |c|
        c.service_name = 'android-spyware'
        c.service_version = '1.0.0'
        
        # Configure Jaeger exporter
        jaeger_exporter = OpenTelemetry::Exporter::Jaeger::AgentExporter.new(
          host: ENV.fetch('JAEGER_HOST', 'localhost'),
          port: ENV.fetch('JAEGER_PORT', 6831).to_i
        )

        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(jaeger_exporter)
        )

        # Add instrumentation
        c.use('OpenTelemetry::Instrumentation::Rack', {
          record_request_hook: ->(span, request) {
            span.set_attribute('http.request.body.size', request.content_length.to_i) if request.content_length
            span.set_attribute('http.user_agent', request.user_agent) if request.user_agent
          }
        })

        c.use('OpenTelemetry::Instrumentation::Rails')
        c.use('OpenTelemetry::Instrumentation::HttpClient')
      end

      @tracer = OpenTelemetry.tracer_provider.tracer('android-spyware-tracer', '1.0.0')
    end

    def with_span(name, attributes = {}, &block)
      @tracer.in_span(name, attributes: attributes, &block)
    end

    def trace_msf_operation(operation_name, payload_details = {})
      with_span(
        "msf.#{operation_name}",
        {
          'service.name' => 'metasploit-rpc',
          'operation' => operation_name,
          'payload.name' => payload_details[:name],
          'payload.destination_ip' => payload_details[:destination_ip],
          'payload.destination_port' => payload_details[:destination_port],
          'rpc.service' => 'android/meterpreter/reverse_tcp'
        }
      ) do |span|
        yield(span)
      end
    end

    def trace_rpc_call(method_name, params = {})
      with_span(
        "rpc.call.#{method_name}",
        {
          'rpc.method' => method_name,
          'rpc.service' => 'Msf::RPC::Client',
          'rpc.params' => params.keys.join(',')
        }
      ) do |span|
        yield(span)
      end
    end

    def trace_session_command(session_id, command)
      with_span(
        'session.meterpreter_command',
        {
          'session.id' => session_id,
          'command' => command,
          'command.length' => command.length,
          'timestamp' => Time.now.iso8601
        }
      ) do |span|
        yield(span)
      end
    end

    def trace_adb_operation(adb_command)
      with_span(
        'adb.operation',
        {
          'adb.command' => adb_command,
          'adb.service' => 'Android Debug Bridge',
          'timestamp' => Time.now.iso8601
        }
      ) do |span|
        yield(span)
      end
    end

    def trace_apk_generation(apk_name, ip, port)
      with_span(
        'apk.generation',
        {
          'apk.name' => apk_name,
          'apk.destination_ip' => ip,
          'apk.destination_port' => port,
          'payload.type' => 'android/meterpreter/reverse_tcp',
          'timestamp' => Time.now.iso8601
        }
      ) do |span|
        yield(span)
      end
    end

    def record_error(span, exception, operation_name)
      span.record_exception(exception)
      span.set_attribute('error', true)
      span.set_attribute('error.kind', exception.class.name)
      span.set_attribute('error.message', exception.message)
      span.set_attribute('error.operation', operation_name)
      span.set_attribute('error.timestamp', Time.now.iso8601)
    end
  end
end
