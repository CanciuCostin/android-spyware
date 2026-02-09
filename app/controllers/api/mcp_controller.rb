# frozen_string_literal: true

module Api
  class McpController < BaseController
    skip_before_action :authenticate_device!, raise: false
    before_action :authenticate_mcp!
    before_action :set_mcp_server

    # POST /api/mcp/initialize
    def initialize_session
      render json: {
        jsonrpc: '2.0',
        result: @server.server_info,
        id: params[:id]
      }
    end

    # GET /api/mcp/tools
    def list_tools
      render json: { jsonrpc: '2.0', result: { tools: @server.list_tools }, id: params[:id] }
    end

    # POST /api/mcp/tools/call
    def call_tool
      name = params.dig(:params, :name) || params[:name]
      arguments = (params.dig(:params, :arguments) || params[:arguments] || {}).to_unsafe_h

      result = @server.call_tool(name: name, arguments: arguments, auth: @mcp_auth)
      render json: { jsonrpc: '2.0', result: result, id: params[:id] }
    rescue Mcp::McpServer::ToolNotFoundError => e
      render json: { jsonrpc: '2.0', error: { code: -32601, message: e.message }, id: params[:id] }, status: :not_found
    rescue Mcp::McpAuth::AuthorizationError => e
      render json: { jsonrpc: '2.0', error: { code: -32600, message: e.message }, id: params[:id] }, status: :forbidden
    end

    # GET /api/mcp/resources
    def list_resources
      render json: { jsonrpc: '2.0', result: { resources: @server.list_resources }, id: params[:id] }
    end

    # POST /api/mcp/resources/read
    def read_resource
      uri = params.dig(:params, :uri) || params[:uri]
      result = @server.read_resource(uri: uri, auth: @mcp_auth)
      render json: { jsonrpc: '2.0', result: result, id: params[:id] }
    rescue Mcp::McpServer::ResourceNotFoundError => e
      render json: { jsonrpc: '2.0', error: { code: -32601, message: e.message }, id: params[:id] }, status: :not_found
    rescue Mcp::McpAuth::AuthorizationError => e
      render json: { jsonrpc: '2.0', error: { code: -32600, message: e.message }, id: params[:id] }, status: :forbidden
    end

    # GET /api/mcp/prompts
    def list_prompts
      render json: { jsonrpc: '2.0', result: { prompts: @server.list_prompts }, id: params[:id] }
    end

    # POST /api/mcp/prompts/get
    def get_prompt
      name = params.dig(:params, :name) || params[:name]
      arguments = (params.dig(:params, :arguments) || params[:arguments] || {}).to_unsafe_h

      result = @server.get_prompt(name: name, arguments: arguments, auth: @mcp_auth)
      render json: { jsonrpc: '2.0', result: result, id: params[:id] }
    rescue Mcp::McpServer::PromptNotFoundError => e
      render json: { jsonrpc: '2.0', error: { code: -32601, message: e.message }, id: params[:id] }, status: :not_found
    rescue Mcp::McpAuth::AuthorizationError => e
      render json: { jsonrpc: '2.0', error: { code: -32600, message: e.message }, id: params[:id] }, status: :forbidden
    end

    # GET /api/mcp/stream/:device_id
    def stream
      streaming = Mcp::McpStreaming.new(auth: @mcp_auth)
      event_types = (params[:event_types] || 'location,command,status').split(',')

      response.headers['Content-Type'] = 'text/event-stream'
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Connection'] = 'keep-alive'

      sse = streaming.sse_stream(device_id: params[:device_id], event_types: event_types)
      sse.each { |event| response.stream.write(event) }
    rescue Mcp::McpAuth::AuthorizationError => e
      render json: { error: e.message }, status: :forbidden
    rescue ActionController::Live::ClientDisconnected
      # Client disconnected, clean up
    ensure
      response.stream.close if response.stream.respond_to?(:close)
    end

    # GET /api/mcp/health
    def health
      render json: {
        status: 'ok',
        server: Mcp::McpConfig.server_name,
        version: Mcp::McpConfig.server_version,
        protocol: Mcp::McpConfig.protocol_version,
        tools_count: @server.list_tools.size,
        resources_count: @server.list_resources.size,
        prompts_count: @server.list_prompts.size,
        rate_limit: {
          remaining: @mcp_auth.remaining_requests,
          limit: Mcp::McpConfig.rate_limit_requests,
          window: Mcp::McpConfig.rate_limit_window
        }
      }
    end

    private

    def authenticate_mcp!
      api_key = extract_api_key
      @mcp_auth = Mcp::McpAuth.new(api_key: api_key)
      @mcp_auth.authenticate!
    rescue Mcp::McpAuth::AuthenticationError => e
      render json: { jsonrpc: '2.0', error: { code: -32600, message: e.message } }, status: :unauthorized
    rescue Mcp::McpAuth::RateLimitError => e
      render json: { jsonrpc: '2.0', error: { code: -32600, message: e.message } }, status: :too_many_requests
    end

    def extract_api_key
      # Bearer token from Authorization header
      auth_header = request.headers['Authorization']
      if auth_header&.start_with?('Bearer ')
        return auth_header.sub('Bearer ', '')
      end

      # X-API-Key header
      params[:api_key] || request.headers['X-API-Key'] || ''
    end

    def set_mcp_server
      @server = Mcp::McpServer.new
    end
  end
end
