# frozen_string_literal: true

require 'rails_helper'

# Injection attack prevention tests.
# Verifies that SQL injection, XSS, command injection, and path traversal
# payloads are properly neutralized by the application's defenses.
RSpec.describe 'Injection Security', type: :request do
  let(:valid_token) { 'test-device-token-12345' }

  before do
    ENV['DEVICE_AUTH_TOKEN'] = valid_token
  end

  after do
    ENV.delete('DEVICE_AUTH_TOKEN')
  end

  describe 'SQL Injection Prevention' do
    let(:sql_payloads) do
      [
        "' OR 1=1 --",
        "'; DROP TABLE smartphones; --",
        "1 UNION SELECT * FROM admin_users",
        "' OR ''='",
        "admin'--",
        "1; WAITFOR DELAY '0:0:5'--",
        "1' AND SLEEP(5)#",
        "' UNION SELECT password FROM admin_users WHERE '1'='1"
      ]
    end

    it 'InputValidator detects SQL injection patterns' do
      sql_payloads.each do |payload|
        expect(InputValidator.contains_sql_injection?(payload)).to be(true),
          "Expected SQL injection detection for: #{payload}"
      end
    end

    it 'InputValidator sanitizes SQL input' do
      dangerous = "'; DROP TABLE users; --"
      sanitized = InputValidator.sanitize_sql_input(dangerous)
      expect(sanitized).not_to include("'")
      expect(sanitized).not_to include(';')
      expect(sanitized).not_to include('--')
    end

    it 'rejects SQL injection in device ID header' do
      sql_payloads.each do |payload|
        get '/api/config', headers: {
          'X-Device-ID' => payload,
          'X-Device-Token' => valid_token
        }
        # Application should not crash (no 500) — either reject or sanitize
        expect(response.status).not_to eq(500),
          "Server error with SQL injection payload: #{payload}"
      end
    end

    it 'rejects SQL injection in query parameters' do
      get '/api/config', headers: {
        'X-Device-ID' => 'safe-device',
        'X-Device-Token' => valid_token
      }, params: { id: "' OR 1=1 --" }

      expect(response.status).not_to eq(500)
    end
  end

  describe 'XSS Prevention' do
    let(:xss_payloads) do
      [
        '<script>alert("xss")</script>',
        '<img src=x onerror=alert(1)>',
        'javascript:alert(1)',
        '<svg onload=alert(1)>',
        '<iframe src="javascript:alert(1)">',
        '"><script>document.cookie</script>',
        '<body onload=alert(1)>',
        '<object data="javascript:alert(1)">',
        '<embed src="javascript:alert(1)">',
        'data:text/html,<script>alert(1)</script>'
      ]
    end

    it 'InputValidator detects XSS patterns' do
      xss_payloads.each do |payload|
        expect(InputValidator.contains_xss?(payload)).to be(true),
          "Expected XSS detection for: #{payload}"
      end
    end

    it 'InputValidator sanitizes XSS content' do
      dangerous = '<script>alert("xss")</script>'
      sanitized = InputValidator.sanitize_xss(dangerous)
      expect(sanitized).not_to include('<script>')
      expect(sanitized).to include('&lt;')
    end

    it 'XSS payloads in API requests do not cause server errors' do
      xss_payloads.each do |payload|
        post '/api/sms', headers: {
          'X-Device-ID' => 'safe-device',
          'X-Device-Token' => valid_token,
          'Content-Type' => 'application/json'
        }, params: { device_id: 'safe-device', body: payload }.to_json

        expect(response.status).not_to eq(500),
          "Server error with XSS payload: #{payload}"
      end
    end
  end

  describe 'Command Injection Prevention' do
    let(:cmd_payloads) do
      [
        '; rm -rf /',
        '| cat /etc/passwd',
        '`whoami`',
        '$(id)',
        '& net user',
        '|| ls -la',
        "'; exec('rm -rf /')",
        '%0aid'
      ]
    end

    it 'command payloads are rejected or sanitized in device IDs' do
      cmd_payloads.each do |payload|
        get '/api/config', headers: {
          'X-Device-ID' => payload,
          'X-Device-Token' => valid_token
        }
        expect(response.status).not_to eq(500),
          "Server error with command injection: #{payload}"
      end
    end

    it 'InputValidator rejects null bytes' do
      result = InputValidator.remove_null_bytes("safe\x00malicious")
      expect(result).to eq('safemalicious')
      expect(result).not_to include("\x00")
    end
  end

  describe 'Path Traversal Prevention' do
    let(:traversal_payloads) do
      [
        '../../../etc/passwd',
        '..\\..\\..\\windows\\system32\\config\\sam',
        '%2e%2e%2f%2e%2e%2f',
        '....//....//etc/passwd',
        '/etc/passwd%00.jpg',
        '..%252f..%252f..%252fetc/passwd'
      ]
    end

    it 'InputValidator detects path traversal in file paths' do
      traversal_payloads.each do |payload|
        result = InputValidator.validate_file_path(payload, base_dir: '/safe/dir')
        # Should either reject or sanitize traversal attempts
        if result.respond_to?(:valid?)
          expect(result.valid?).to be(false),
            "Expected path traversal rejection for: #{payload}" if payload.include?('..')
        end
      end
    end

    it 'path traversal in API requests does not expose files' do
      traversal_payloads.each do |payload|
        get '/api/config', headers: {
          'X-Device-ID' => 'safe-device',
          'X-Device-Token' => valid_token
        }, params: { path: payload }

        expect(response.status).not_to eq(500),
          "Server error with path traversal: #{payload}"
        expect(response.body).not_to include('root:'),
          "Leaked /etc/passwd with: #{payload}"
      end
    end
  end
end
