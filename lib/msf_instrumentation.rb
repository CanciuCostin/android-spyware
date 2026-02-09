# frozen_string_literal: true

begin
  require 'msfrpc-client'
rescue LoadError
  # Gem not installed (e.g. Windows native)
end
require 'date'
require_relative '../lib/spyware_tracing'

module MsfInstrumentation
  def self.initialize_msf_tracing
    SpywareTracing.initialize_tracing
  end

  module ApplicationControllerMixin
    # Placeholder for future instrumentation needs
    # Legacy MSF process management has been removed
  end
end
