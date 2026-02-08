# frozen_string_literal: true

# Provides constructor-based dependency injection with sensible defaults.
#
# Usage:
#   class MyService
#     include DependencyInjectable
#
#     dependency :broadcaster, default: -> { ActionCable.server }
#     dependency :validator,   default: -> { InputValidator }
#     dependency :logger,      default: -> { StructuredLogger }
#
#     def initialize(device, **deps)
#       @device = device
#       inject_dependencies(deps)
#     end
#   end
#
#   # Production — uses defaults:
#   MyService.new(device)
#
#   # Test — inject doubles:
#   MyService.new(device, broadcaster: fake_broadcaster)
module DependencyInjectable
  extend ActiveSupport::Concern

  class_methods do
    # Declare a named dependency with a lazy default.
    # The +default+ proc is evaluated on first access (lazy initialization).
    def dependency(name, default:)
      @_dependencies ||= {}
      @_dependencies[name] = default

      # Define lazy reader
      define_method(name) do
        ivar = :"@_dep_#{name}"
        unless instance_variable_defined?(ivar)
          factory = self.class.dependencies[name]
          instance_variable_set(ivar, factory.call)
        end
        instance_variable_get(ivar)
      end

      private name
    end

    # Returns the dependency registry (including inherited ones).
    def dependencies
      parent = superclass.respond_to?(:dependencies) ? superclass.dependencies : {}
      parent.merge(@_dependencies || {})
    end
  end

  private

  # Call from initialize to inject overrides supplied via keyword args.
  def inject_dependencies(overrides = {})
    self.class.dependencies.each_key do |dep_name|
      next unless overrides.key?(dep_name)

      instance_variable_set(:"@_dep_#{dep_name}", overrides[dep_name])
    end
  end
end
