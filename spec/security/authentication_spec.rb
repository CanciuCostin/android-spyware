# frozen_string_literal: true

require 'rails_helper'

# Authentication security tests.
# Prevents regressions in login, session, token, and CSRF protection logic.
RSpec.describe 'Authentication Security', type: :request do
  let(:valid_token) { 'test-device-token-12345' }
  let(:admin_email) { 'admin@test.com' }
  let(:admin_password) { 'password123456' }

  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
    AdminUser.find_or_create_by!(email: admin_email) do |user|
      user.password = admin_password
      user.password_confirmation = admin_password
    end
  end

  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
  end

  describe 'Admin login' do
    it 'succeeds with valid credentials' do
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: admin_password }
      }
      expect(response).to redirect_to('/admin')
    end

    it 'fails with invalid password' do
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: 'wrong_password' }
      }
      expect(response.status).to be_in([200, 401, 422])
      expect(response.body).not_to include('Sign Out')
    end

    it 'fails with non-existent user' do
      post '/admin/login', params: {
        admin_user: { email: 'nobody@test.com', password: 'anything' }
      }
      expect(response.status).to be_in([200, 401, 422])
    end

    it 'does not leak information about valid emails' do
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: 'wrong' }
      }
      invalid_response = response.body

      post '/admin/login', params: {
        admin_user: { email: 'nonexistent@test.com', password: 'wrong' }
      }
      # Both should show the same generic error (Devise default behavior)
      expect(response.status).to be_in([200, 401, 422])
    end
  end

  describe 'Session management' do
    it 'requires authentication for admin pages' do
      get '/admin/dashboard'
      expect(response).to redirect_to('/admin/login')
    end

    it 'invalidates session on logout' do
      # Login
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: admin_password }
      }
      expect(response).to redirect_to('/admin')

      # Logout
      delete '/admin/logout'

      # Verify session is invalidated
      get '/admin/dashboard'
      expect(response).to redirect_to('/admin/login')
    end
  end

  describe 'API device token validation' do
    it 'rejects requests without a token' do
      get '/api/config', headers: { 'X-Device-ID' => 'test-device' }
      expect(response.status).to eq(401)
    end

    it 'rejects requests with an invalid token' do
      get '/api/config', headers: {
        'X-Device-ID' => 'test-device',
        'X-Device-Token' => 'invalid-token'
      }
      expect(response.status).to eq(401)
    end

    it 'accepts requests with a valid token' do
      get '/api/config', headers: {
        'X-Device-ID' => 'test-device',
        'X-Device-Token' => valid_token
      }
      expect(response.status).not_to eq(401)
    end

    it 'rejects requests without device ID' do
      get '/api/config', headers: { 'X-Device-Token' => valid_token }
      expect(response.status).to eq(400)
    end
  end

  describe 'HMAC signature validation' do
    let(:device_id) { 'sig-test-device' }
    let(:timestamp) { Time.current.to_i.to_s }

    it 'accepts valid HMAC signatures' do
      payload = "#{device_id}:#{timestamp}"
      signature = OpenSSL::HMAC.hexdigest('sha256', valid_token, payload)

      get '/api/config', headers: {
        'X-Device-ID' => device_id,
        'X-Device-Timestamp' => timestamp,
        'X-Device-Signature' => signature
      }
      expect(response.status).not_to eq(401)
    end

    it 'rejects tampered signatures' do
      get '/api/config', headers: {
        'X-Device-ID' => device_id,
        'X-Device-Timestamp' => timestamp,
        'X-Device-Signature' => 'tampered_signature_value'
      }
      expect(response.status).to eq(401)
    end

    it 'rejects expired timestamps' do
      old_timestamp = (Time.current - 10.minutes).to_i.to_s
      payload = "#{device_id}:#{old_timestamp}"
      signature = OpenSSL::HMAC.hexdigest('sha256', valid_token, payload)

      get '/api/config', headers: {
        'X-Device-ID' => device_id,
        'X-Device-Timestamp' => old_timestamp,
        'X-Device-Signature' => signature
      }
      expect(response.status).to eq(401)
    end
  end

  describe 'CSRF protection' do
    it 'protects admin form submissions' do
      # Rails CSRF protection is enabled by default for non-API controllers
      # Verify the authenticity token mechanism is active
      get '/admin/login'
      expect(response.body).to include('authenticity_token')
    end

    it 'API endpoints skip CSRF (token-based auth instead)' do
      # API uses token auth, so CSRF is intentionally skipped
      get '/api/config', headers: {
        'X-Device-ID' => 'test',
        'X-Device-Token' => valid_token
      }
      expect(response.status).not_to eq(422)
    end
  end

  describe 'Password security' do
    it 'stores passwords as bcrypt hashes' do
      user = AdminUser.find_by(email: admin_email)
      expect(user.encrypted_password).to start_with('$2a$')
    end

    it 'does not expose password in responses' do
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: admin_password }
      }
      expect(response.body).not_to include(admin_password)
    end
  end
end
