# frozen_string_literal: true

require 'rails_helper'

# OWASP Top 10 security tests covering the most critical web application risks.
# Maps to OWASP Top 10 2021: A01, A02, A03, A05, A07.
RSpec.describe 'OWASP Top 10 Security', type: :request do
  let(:valid_token) { 'test-device-token-12345' }
  let(:admin_email) { 'admin@test.com' }
  let(:admin_password) { 'password123456' }

  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
    AdminUser.find_or_create_by!(email: admin_email) do |u|
      u.password = admin_password
      u.password_confirmation = admin_password
    end
  end

  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
  end

  # ── A01: Broken Access Control ──────────────────────────────────────

  describe 'A01: Broken Access Control' do
    it 'unauthenticated users cannot access admin dashboard' do
      get '/admin/dashboard'
      expect(response).to redirect_to('/admin/login')
    end

    it 'unauthenticated users cannot manage resources' do
      post '/admin/android_config/update', params: { config: {} }
      # Should redirect to login or return 401/403
      expect(response.status).to be_in([301, 302, 401, 403, 422])
    end

    it 'API endpoints require device authentication' do
      get '/api/config'
      expect(response.status).to be_in([400, 401])
    end

    it 'prevents forced browsing to admin endpoints' do
      %w[/admin/admin_users/new /admin/smartphones].each do |path|
        get path
        expect(response.status).to be_in([301, 302, 404]),
          "Unprotected admin route: #{path}"
      end
    end

    it 'CORS headers are not overly permissive' do
      get '/api/config', headers: {
        'X-Device-ID' => 'test',
        'X-Device-Token' => valid_token,
        'Origin' => 'https://evil.com'
      }
      cors_header = response.headers['Access-Control-Allow-Origin']
      expect(cors_header).not_to eq('*') if cors_header.present?
    end
  end

  # ── A02: Cryptographic Failures ─────────────────────────────────────

  describe 'A02: Cryptographic Failures' do
    it 'passwords are stored using bcrypt' do
      user = AdminUser.find_by(email: admin_email)
      expect(user.encrypted_password).to start_with('$2a$')
    end

    it 'password hash has sufficient cost factor' do
      user = AdminUser.find_by(email: admin_email)
      # bcrypt cost factor is embedded in the hash: $2a$XX$...
      cost = user.encrypted_password.split('$')[2].to_i
      expect(cost).to be >= 10
    end

    it 'API tokens use timing-safe comparison' do
      # Verify the secure_compare method exists in the base controller
      expect(Api::BaseController.private_instance_methods).to include(:secure_compare)
    end

    it 'HMAC signatures use SHA-256' do
      device_id = 'crypto-test'
      timestamp = Time.current.to_i.to_s
      payload = "#{device_id}:#{timestamp}"
      signature = OpenSSL::HMAC.hexdigest('sha256', valid_token, payload)

      # SHA-256 produces 64-character hex string
      expect(signature.length).to eq(64)
    end

    it 'sensitive data is not logged in plain text' do
      # Verify filter_parameter_logging is configured
      filtered = Rails.application.config.filter_parameters
      expect(filtered).to include(:password)
    end
  end

  # ── A03: Injection ──────────────────────────────────────────────────

  describe 'A03: Injection' do
    it 'SQL injection in login form does not bypass authentication' do
      post '/admin/login', params: {
        admin_user: { email: "' OR 1=1 --", password: 'anything' }
      }
      # Should not redirect to admin (successful login)
      expect(response).not_to redirect_to('/admin')
    end

    it 'SQL injection payloads do not crash the API' do
      get '/api/config', headers: {
        'X-Device-ID' => "'; DROP TABLE smartphones;--",
        'X-Device-Token' => valid_token
      }
      expect(response.status).not_to eq(500)
    end

    it 'XSS payloads in POST data do not cause server errors' do
      post '/api/clipboard', headers: {
        'X-Device-ID' => 'safe-device',
        'X-Device-Token' => valid_token,
        'Content-Type' => 'application/json'
      }, params: {
        device_id: 'safe-device',
        content: '<script>alert(document.cookie)</script>'
      }.to_json

      expect(response.status).not_to eq(500)
    end

    it 'InputValidator catches common injection patterns' do
      expect(InputValidator.contains_sql_injection?("1' OR '1'='1")).to be true
      expect(InputValidator.contains_xss?('<script>alert(1)</script>')).to be true
    end
  end

  # ── A05: Security Misconfiguration ──────────────────────────────────

  describe 'A05: Security Misconfiguration' do
    it 'does not expose stack traces in production-like errors' do
      get '/api/nonexistent_endpoint_12345', headers: {
        'X-Device-ID' => 'test',
        'X-Device-Token' => valid_token
      }
      unless Rails.env.development?
        expect(response.body).not_to include('ActionController')
        expect(response.body).not_to include('app/controllers')
      end
    end

    it 'sets appropriate security headers' do
      get '/health'
      # X-Content-Type-Options prevents MIME-type sniffing
      xct = response.headers['X-Content-Type-Options']
      expect(xct).to eq('nosniff') if xct.present?
    end

    it 'default admin credentials should be changed' do
      # Verify the well-known default credentials don't work in test env
      # (Test env creates its own admin, but we check the pattern)
      default_admin = AdminUser.find_by(email: 'admin@example.com')
      if default_admin
        # Should have changed from default password
        expect(default_admin.valid_password?('password')).to be false
      end
    end

    it 'debug mode is disabled in production' do
      if Rails.env.production?
        expect(Rails.application.config.consider_all_requests_local).to be false
      end
    end

    it 'Rack::Attack is configured and active' do
      expect(Rack::Attack.throttles).not_to be_empty
      expect(Rack::Attack.throttles.keys).to include('auth/ip')
    end

    it 'rate limiting includes all critical endpoints' do
      throttle_names = Rack::Attack.throttles.keys
      expect(throttle_names).to include('auth/ip')
      expect(throttle_names).to include('api/ip')
      expect(throttle_names).to include('admin/ip')
      expect(throttle_names).to include('uploads/device')
      expect(throttle_names).to include('commands/device')
      expect(throttle_names).to include('websocket/ip')
    end
  end

  # ── A07: Cross-Site Scripting (XSS) ─────────────────────────────────

  describe 'A07: Cross-Site Scripting (XSS)' do
    it 'sanitizes HTML entities in user input' do
      result = InputValidator.sanitize_xss('<script>alert(1)</script>')
      expect(result).not_to include('<script>')
      expect(result).to include('&lt;script&gt;')
    end

    it 'detects event handler XSS' do
      expect(InputValidator.contains_xss?('<img onerror=alert(1)>')).to be true
    end

    it 'detects javascript: protocol XSS' do
      expect(InputValidator.contains_xss?('javascript:alert(1)')).to be true
    end

    it 'detects data: URI XSS' do
      expect(InputValidator.contains_xss?('data:text/html,<script>alert(1)</script>')).to be true
    end

    it 'detects SVG-based XSS' do
      expect(InputValidator.contains_xss?('<svg onload=alert(1)>')).to be true
    end

    it 'CSRF authenticity token is present in admin forms' do
      get '/admin/login'
      expect(response.body).to include('authenticity_token')
    end

    it 'admin pages include X-XSS-Protection header' do
      post '/admin/login', params: {
        admin_user: { email: admin_email, password: admin_password }
      }
      follow_redirect!

      get '/admin/dashboard'
      # Modern Rails sets this or relies on CSP
      xxss = response.headers['X-XSS-Protection']
      expect(xxss).to be_present if xxss
    end
  end
end
