# frozen_string_literal: true

module Mcp
  class McpServer
    attr_reader :tools, :resources, :prompts

    def initialize
      @tools = {}
      @resources = {}
      @prompts = {}
      register_all
    end

    def server_info
      {
        name: McpConfig.server_name,
        version: McpConfig.server_version,
        protocolVersion: McpConfig.protocol_version,
        capabilities: {
          tools: { listChanged: false },
          resources: { subscribe: true, listChanged: false },
          prompts: { listChanged: false }
        }
      }
    end

    # --- Tool Execution ---

    def list_tools
      @tools.values.map { |t| t[:schema] }
    end

    def call_tool(name:, arguments: {}, auth:)
      tool = @tools[name]
      raise ToolNotFoundError, "Unknown tool: #{name}" unless tool

      auth.authorize!(tool[:scope])
      auth.audit_log(action: 'tool_call', resource: name, details: arguments)

      tool[:handler].call(arguments.deep_symbolize_keys)
    end

    # --- Resource Access ---

    def list_resources
      @resources.values.map { |r| r[:schema] }
    end

    def read_resource(uri:, auth:)
      template_key, params = match_resource(uri)
      raise ResourceNotFoundError, "Unknown resource: #{uri}" unless template_key

      resource = @resources[template_key]
      auth.authorize!(resource[:scope])
      auth.audit_log(action: 'resource_read', resource: uri)

      resource[:handler].call(params)
    end

    # --- Prompt Retrieval ---

    def list_prompts
      @prompts.values.map { |p| p[:schema] }
    end

    def get_prompt(name:, arguments: {}, auth:)
      prompt = @prompts[name]
      raise PromptNotFoundError, "Unknown prompt: #{name}" unless prompt

      auth.authorize!(prompt[:scope])
      auth.audit_log(action: 'prompt_get', resource: name, details: arguments)

      prompt[:handler].call(arguments.deep_symbolize_keys)
    end

    # --- Registration Helpers ---

    def register_tool(name:, description:, input_schema:, scope:, &handler)
      @tools[name] = {
        schema: { name: name, description: description, inputSchema: input_schema },
        scope: scope,
        handler: handler
      }
    end

    def register_resource(uri_template:, name:, description:, mime_type: 'application/json', scope:, &handler)
      @resources[uri_template] = {
        schema: {
          uriTemplate: uri_template,
          name: name,
          description: description,
          mimeType: mime_type
        },
        scope: scope,
        handler: handler
      }
    end

    def register_prompt(name:, description:, arguments:, scope:, &handler)
      @prompts[name] = {
        schema: { name: name, description: description, arguments: arguments },
        scope: scope,
        handler: handler
      }
    end

    class ToolNotFoundError < StandardError; end
    class ResourceNotFoundError < StandardError; end
    class PromptNotFoundError < StandardError; end

    private

    def register_all
      Tools::DeviceTools.new(self).register
      Tools::DataTools.new(self).register
      Tools::CommandTools.new(self).register
      Tools::AnalysisTools.new(self).register
      Resources::DeviceResources.new(self).register
      Prompts::PromptTemplates.new(self).register
    end

    def match_resource(uri)
      @resources.each do |template, _config|
        pattern = template.gsub(/\{(\w+)\}/, '(?<\1>[^/]+)')
        match = uri.match(/\A#{pattern}\z/)
        next unless match

        params = match.named_captures.symbolize_keys
        return [template, params]
      end
      nil
    end
  end
end
