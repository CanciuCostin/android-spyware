# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::McpAuth, type: :service do
  let(:valid_key) { "test-key" }
  let(:invalid_key) { "wrong-key" }
  let(:scopes) { ["devices:read", "data:read"] }

  before do
    allow(Mcp::McpConfig).to receive(:valid_api_key?).with(valid_key).and_return(true)
    allow(Mcp::McpConfig).to receive(:valid_api_key?).with(invalid_key).and_return(false)
    allow(Mcp::McpConfig).to receive(:scopes_for_key).with(valid_key).and_return(scopes)
    allow(Mcp::McpConfig).to receive(:rate_limit_requests).and_return(100)
    allow(Mcp::McpConfig).to receive(:rate_limit_window).and_return(60)
  end

  describe '#authenticate!' do
    it 'authenticates with a valid key' do
      auth = described_class.new(api_key: valid_key)
      expect(auth.authenticate!).to be true
    end

    it 'raises error with an invalid key' do
      auth = described_class.new(api_key: invalid_key)
      expect { auth.authenticate! }.to raise_error(Mcp::McpAuth::AuthenticationError)
    end
  end

  describe '#authorize!' do
    let(:auth) { described_class.new(api_key: valid_key) }

    it 'authorizes a valid scope' do
      expect(auth.authorize!('devices:read')).to be true
    end

    it 'raises error for missing scope' do
      expect { auth.authorize!('admin') }.to raise_error(Mcp::McpAuth::AuthorizationError)
    end

    it 'handles wildcard scopes' do
      allow(Mcp::McpConfig).to receive(:scopes_for_key).with(valid_key).and_return(["devices:*"])
      expect(auth.authorize!('devices:write')).to be true
    end
  end
end
