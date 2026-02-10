# frozen_string_literal: true

module Mcp
  module Tools
    class CommandTools
      def initialize(server)
        @server = server
      end

      def register
        register_send_command
        register_get_command_status
        register_get_command_history
        register_schedule_command
      end

      private

      def register_send_command
        @server.register_tool(
          name: 'send_command',
          description: 'Send a command to a device. Returns a request ID for tracking.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              command: { type: 'string', description: 'Command name (e.g., dump_contacts, take_picture, shell_command)' },
              params: { type: 'object', description: 'Command parameters', default: {} }
            },
            required: %w[device_id command]
          },
          scope: 'commands:execute'
        ) do |args|
          device = find_device!(args[:device_id])
          # Validate command against whitelist before execution
          validation = CommandValidator.validate(args[:command], args[:params] || {})
          unless validation.valid?
            next {
              content: [{ type: 'text', text: { status: 'error', error: validation.error }.to_json }],
              isError: true
            }
          end
          result = DeviceCommandService.call(device, args[:command], args[:params] || {})

          if result.success?
            {
              content: [{
                type: 'text',
                text: {
                  status: 'sent',
                  device_id: device.device_id,
                  command: args[:command],
                  request_id: result.value&.dig(:request_id) || result.value
                }.to_json
              }]
            }
          else
            {
              content: [{
                type: 'text',
                text: { status: 'error', error: result.error }.to_json
              }],
              isError: true
            }
          end
        end
      end

      def register_get_command_status
        @server.register_tool(
          name: 'get_command_status',
          description: 'Check the status of a previously sent command by request ID.',
          input_schema: {
            type: 'object',
            properties: {
              request_id: { type: 'string', description: 'Command request ID' }
            },
            required: ['request_id']
          },
          scope: 'commands:execute'
        ) do |args|
          command = PendingCommand.find_by(request_id: args[:request_id])
          raise McpServer::ToolNotFoundError, "Command not found: #{args[:request_id]}" unless command

          {
            content: [{
              type: 'text',
              text: {
                request_id: command.request_id,
                command: command.command,
                status: command.status,
                created_at: command.created_at.iso8601,
                completed_at: command.completed_at&.iso8601,
                response_data: command.response_data
              }.to_json
            }]
          }
        end
      end

      def register_get_command_history
        @server.register_tool(
          name: 'get_command_history',
          description: 'Get command execution history for a device.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              status: { type: 'string', enum: %w[pending processing completed failed timeout], description: 'Filter by status' },
              limit: { type: 'integer', description: 'Max results (default: 25)', default: 25 }
            },
            required: ['device_id']
          },
          scope: 'commands:execute'
        ) do |args|
          device = find_device!(args[:device_id])
          limit = [[args[:limit] || 25, 1].max, McpConfig.max_results].min

          commands = device.pending_commands.order(created_at: :desc)
          commands = commands.where(status: args[:status]) if args[:status].present?
          commands = commands.limit(limit)

          {
            content: [{
              type: 'text',
              text: {
                device_id: device.device_id,
                commands: commands.map { |c|
                  {
                    request_id: c.request_id,
                    command: c.command,
                    status: c.status,
                    created_at: c.created_at.iso8601,
                    completed_at: c.completed_at&.iso8601
                  }
                },
                count: commands.size
              }.to_json
            }]
          }
        end
      end

      def register_schedule_command
        @server.register_tool(
          name: 'schedule_command',
          description: 'Schedule a recurring command for a device using a cron expression.',
          input_schema: {
            type: 'object',
            properties: {
              device_id: { type: 'string', description: 'Device identifier' },
              command: { type: 'string', description: 'Command name' },
              cron_expression: { type: 'string', description: 'Cron expression (e.g., "0 */6 * * *" for every 6 hours)' },
              params: { type: 'object', description: 'Command parameters', default: {} },
              max_runs: { type: 'integer', description: 'Maximum number of executions (0 = unlimited)', default: 0 }
            },
            required: %w[device_id command cron_expression]
          },
          scope: 'commands:schedule'
        ) do |args|
          device = find_device!(args[:device_id])

          unless CommandSchedulerService.valid_cron?(args[:cron_expression])
            next {
              content: [{ type: 'text', text: { status: 'error', error: 'Invalid cron expression' }.to_json }],
              isError: true
            }
          end

          scheduled = device.scheduled_commands.create!(
            command: args[:command],
            cron_expression: args[:cron_expression],
            params: args[:params] || {},
            max_runs: args[:max_runs] || 0,
            active: true
          )

          {
            content: [{
              type: 'text',
              text: {
                status: 'scheduled',
                id: scheduled.id,
                device_id: device.device_id,
                command: args[:command],
                cron_expression: args[:cron_expression],
                next_run: CommandSchedulerService.next_run_time(args[:cron_expression])&.iso8601
              }.to_json
            }]
          }
        end
      end

      def find_device!(device_id)
        Smartphone.find_by!(device_id: device_id)
      rescue ActiveRecord::RecordNotFound
        raise McpServer::ToolNotFoundError, "Device not found: #{device_id}"
      end
    end
  end
end
