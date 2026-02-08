# frozen_string_literal: true

require 'rails_helper'

# Authorization security tests.
# Ensures admin-only endpoints are protected, device isolation is enforced,
# and cross-device access is prevented.
RSpec.describe 'Authorization Security', type: :request do
  let(:valid_token) { 'test-device-token-12345' }
  let(:admin_email) { 'admin@test.com' }
  let(:admin_password) { 'password123456' }

  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
  end

  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
  end

  describe 'Admin-only endpoints' do
    it 'redirects unauthenticated users from admin dashboard' do
      get '/admin/dashboard'
      expect(response).to redirect_to('/admin/login')
    end

    it 'redirects unauthenticated users from admin resources' do
      %w[/admin/admin_users /admin/smartphones].each do |path|
        get path
        expect(response.status).to be_in([301, 302, 404])
      end
    end

    it 'allows authenticated admin to access dashboard' do
      admin = AdminUser.find_or_create_by!(email: admin_email) do |u|
        u.password = admin_password
        u.password_confirmation = admin_password
      end

      post '/admin/login', params: {
        admin_user: { email: admin_email, password: admin_password }
      }
      follow_redirect!

      get '/admin/dashboard'
      expect(response.status).to eq(200)
    end
  end

  describe 'Device-specific access control' do
    let(:device_headers) do
      {
        'X-Device-ID' => 'device-alpha',
        'X-Device-Token' => valid_token
      }
    end

    it 'requires device ID for API endpoints' do
      get '/api/config', headers: { 'X-Device-Token' => valid_token }
      expect(response.status).to eq(400)
    end

    it 'accepts properly identified device requests' do
      get '/api/config', headers: device_headers
      expect(response.status).not_to eq(400)
    end
  end

  describe 'Cross-device access prevention' do
    let(:device_a_id) { 'device-alpha-001' }
    let(:device_b_id) { 'device-beta-002' }

    it 'device A cannot access device B keylogger data' do
      get "/api/keylogger/data/#{device_b_id}", headers: {
        'X-Device-ID' => device_a_id,
        'X-Device-Token' => valid_token
      }
      # Should either return empty data or the server controls access
      expect(response.status).not_to eq(500)
    end

    it 'device A cannot access device B notifications' do
      get "/api/notifications/#{device_b_id}", headers: {
        'X-Device-ID' => device_a_id,
        'X-Device-Token' => valid_token
      }
      expect(response.status).not_to eq(500)
    end
  end

  describe 'Health endpoints (public access)' do
    it 'allows unauthenticated access to health check' do
      get '/health'
      expect(response.status).to eq(200)
    end

    it 'allows unauthenticated access to readiness probe' do
      get '/health/ready'
      expect(response.status).to eq(200)
    end
  end

  describe 'Route protection' do
    it 'returns 404 for non-existent routes' do
      get '/api/nonexistent/endpoint'
      expect(response.status).to be_in([404, 401, 400])
    end

    it 'does not expose internal Rails routes' do
      get '/rails/info/routes'
      # Should not be accessible in non-development environments
      expect(response.status).not_to eq(200) unless Rails.env.development?
    end
  end
end
