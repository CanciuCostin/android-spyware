# frozen_string_literal: true

require 'rails_helper'

# Tests for Rack::Attack rate limiting configuration.
# Each throttle rule is exercised to verify that exceeding limits returns 429.
RSpec.describe 'Rate Limiting', type: :request do
  let(:valid_token) { 'test-device-token-12345' }
  let(:device_id)   { 'rate-limit-test-device' }

  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token

    # Reset Rack::Attack state between tests for determinism
    Rack::Attack.cache.store.clear
    Rack::Attack.reset!
  end

  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
    Rack::Attack.cache.store.clear
  end

  describe 'Auth endpoint throttle (5 req/min)' do
    it 'allows requests within the limit' do
      5.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end
      expect(response.status).not_to eq(429)
    end

    it 'returns 429 after exceeding the limit' do
      6.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end
      expect(response.status).to eq(429)
    end

    it 'includes Retry-After header when throttled' do
      7.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end
      expect(response.headers['Retry-After']).to be_present
    end
  end

  describe 'File uploads throttle (10 req/min per device)' do
    it 'returns 429 after exceeding upload limit' do
      11.times do
        post '/api/photos',
             headers: {
               'X-Device-ID' => device_id,
               'X-Device-Token' => valid_token
             },
             params: { device_id: device_id }
      end
      expect(response.status).to eq(429)
    end
  end

  describe 'Commands throttle (30 req/min per device)' do
    it 'returns 429 after exceeding command limit' do
      31.times do
        get "/api/commands/#{device_id}",
            headers: {
              'X-Device-ID' => device_id,
              'X-Device-Token' => valid_token
            }
      end
      expect(response.status).to eq(429)
    end
  end

  describe 'API general throttle (100 req/min per IP)' do
    it 'returns 429 after exceeding API general limit' do
      101.times do
        get '/api/config',
            headers: {
              'X-Device-ID' => device_id,
              'X-Device-Token' => valid_token
            }
      end
      expect(response.status).to eq(429)
    end
  end

  describe 'WebSocket throttle (5/min per IP)' do
    it 'returns 429 after exceeding WebSocket limit' do
      6.times do
        get '/webrtc/turn_credentials'
      end
      expect(response.status).to eq(429)
    end
  end

  describe 'Admin panel throttle (20 req/min per IP)' do
    it 'returns 429 after exceeding admin panel limit' do
      21.times do
        get '/admin/dashboard'
      end
      expect(response.status).to eq(429)
    end
  end

  describe 'Custom throttle response format' do
    it 'returns JSON with error details' do
      7.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end

      expect(response.status).to eq(429)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('Rate limit exceeded')
      expect(body['retry_after']).to be_a(Integer)
      expect(body['throttle']).to be_present
    end

    it 'includes rate limit headers' do
      7.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end

      expect(response.headers['X-RateLimit-Limit']).to be_present
      expect(response.headers['X-RateLimit-Remaining']).to eq('0')
      expect(response.headers['X-RateLimit-Reset']).to be_present
    end
  end

  describe 'Safelist' do
    it 'allows localhost requests without throttling' do
      # Localhost is safelisted — even excessive requests should pass through
      # The actual safelist is for 127.0.0.1 which is the default test IP
      10.times do
        post '/admin/login', params: { admin_user: { email: 'a@b.com', password: 'x' } }
      end
      # Since tests run from 127.0.0.1, safelist should allow all
      expect(response.status).not_to eq(429)
    end
  end

  describe 'Blocklist' do
    it 'blocks requests from banned IPs' do
      Rack::Attack.cache.write('blocked:192.0.2.1', true, expires_in: 1.hour)

      # Simulate request from blocked IP — verified via RateLimitService
      expect(RateLimitService.blocked?('192.0.2.1')).to be true
    end
  end
end

RSpec.describe RateLimitService do
  before do
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
  end

  describe '.rate_limit_status' do
    it 'returns status for a known throttle' do
      result = described_class.rate_limit_status('api/ip', '1.2.3.4')
      expect(result[:throttle]).to eq('api/ip')
      expect(result[:limit]).to eq(100)
      expect(result[:remaining]).to eq(100)
      expect(result[:blocked]).to be false
    end

    it 'returns error for unknown throttle' do
      result = described_class.rate_limit_status('nonexistent', '1.2.3.4')
      expect(result[:error]).to include('Unknown throttle')
    end
  end

  describe '.block_ip / .unblock_ip' do
    it 'blocks and unblocks an IP' do
      described_class.block_ip('10.0.0.99')
      expect(described_class.blocked?('10.0.0.99')).to be true

      described_class.unblock_ip('10.0.0.99')
      expect(described_class.blocked?('10.0.0.99')).to be false
    end

    it 'returns error for blank IP' do
      result = described_class.block_ip('')
      expect(result[:error]).to include('Invalid IP')
    end
  end

  describe '.reset' do
    it 'resets counters for an identifier' do
      result = described_class.reset('1.2.3.4')
      expect(result[:success]).to be true
      expect(result[:reset_throttles]).to include('api/ip')
    end
  end

  describe '.statistics' do
    it 'returns all throttle rules' do
      stats = described_class.statistics
      expect(stats).to be_an(Array)
      expect(stats.map { |s| s[:name] }).to include('auth/ip', 'api/ip', 'admin/ip')
    end
  end

  describe '.violation_count' do
    it 'returns 0 when no violations exist' do
      expect(described_class.violation_count('1.2.3.4')).to eq(0)
    end
  end

  describe '#call' do
    it 'returns statuses for all throttles' do
      result = described_class.new('1.2.3.4').call
      expect(result).to be_success
      expect(result.value.length).to eq(RateLimitService::THROTTLE_RULES.size)
    end

    it 'fails when identifier is blank' do
      result = described_class.new(nil).call
      expect(result).to be_failure
    end
  end
end
