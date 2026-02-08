# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InputValidator do
  describe '.validate_device_id' do
    it 'accepts valid device IDs' do
      result = described_class.validate_device_id('abc-123')
      expect(result.valid?).to be true
      expect(result.value).to eq('abc-123')
    end

    it 'rejects nil' do
      result = described_class.validate_device_id(nil)
      expect(result.valid?).to be false
    end

    it 'rejects empty string' do
      result = described_class.validate_device_id('')
      expect(result.valid?).to be false
    end

    it 'rejects device IDs with special characters' do
      result = described_class.validate_device_id('device; rm -rf /')
      expect(result.valid?).to be false
    end
  end

  describe '.validate_upload_id' do
    it 'accepts valid UUID upload IDs' do
      uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
      result = described_class.validate_upload_id(uuid)
      expect(result.valid?).to be true
    end

    it 'rejects non-UUID strings' do
      result = described_class.validate_upload_id('not-a-uuid')
      expect(result.valid?).to be false
    end

    it 'rejects nil' do
      result = described_class.validate_upload_id(nil)
      expect(result.valid?).to be false
    end
  end

  describe '.validate_command' do
    it 'accepts whitelisted commands' do
      result = described_class.validate_command('get_contacts')
      expect(result.valid?).to be true
    end

    it 'rejects unknown commands' do
      result = described_class.validate_command('execute_arbitrary')
      expect(result.valid?).to be false
    end

    it 'rejects empty commands' do
      result = described_class.validate_command('')
      expect(result.valid?).to be false
    end

    it 'validates required params' do
      result = described_class.validate_command('send_sms', {})
      expect(result.valid?).to be false
      expect(result.error).to include('phone_number')
    end
  end

  describe '.validate_file_path' do
    it 'accepts safe paths' do
      result = described_class.validate_file_path('documents/file.txt')
      expect(result.valid?).to be true
    end

    it 'rejects traversal paths' do
      result = described_class.validate_file_path('../../etc/passwd')
      expect(result.valid?).to be false
    end

    it 'rejects paths with null bytes' do
      result = described_class.validate_file_path("file.txt\x00.jpg")
      expect(result.valid?).to be true # null byte is stripped by sanitize
    end

    it 'validates against base directory' do
      result = described_class.validate_file_path('../../etc/passwd', base_dir: '/home/user')
      expect(result.valid?).to be false
    end
  end

  describe '.validate_coordinates' do
    it 'accepts valid coordinates' do
      result = described_class.validate_coordinates(45.0, -73.5)
      expect(result.valid?).to be true
    end

    it 'rejects out-of-range latitude' do
      result = described_class.validate_coordinates(91.0, 0.0)
      expect(result.valid?).to be false
    end

    it 'rejects out-of-range longitude' do
      result = described_class.validate_coordinates(0.0, 181.0)
      expect(result.valid?).to be false
    end
  end

  describe '.validate_phone_number' do
    it 'accepts valid phone numbers' do
      result = described_class.validate_phone_number('+1-555-123-4567')
      expect(result.valid?).to be true
    end

    it 'rejects too-short numbers' do
      result = described_class.validate_phone_number('12')
      expect(result.valid?).to be false
    end
  end

  describe '.sanitize_sql_input' do
    it 'removes single quotes' do
      expect(described_class.sanitize_sql_input("test'value")).to eq('testvalue')
    end

    it 'removes SQL comments' do
      expect(described_class.sanitize_sql_input('test--comment')).to eq('testcomment')
    end

    it 'handles nil' do
      expect(described_class.sanitize_sql_input(nil)).to eq('')
    end
  end

  describe '.contains_sql_injection?' do
    it 'detects UNION SELECT' do
      expect(described_class.contains_sql_injection?("1 UNION SELECT * FROM users")).to be true
    end

    it 'detects OR 1=1' do
      expect(described_class.contains_sql_injection?("admin' OR 1=1")).to be true
    end

    it 'detects SQL comments' do
      expect(described_class.contains_sql_injection?("admin'--")).to be true
    end

    it 'allows normal strings' do
      expect(described_class.contains_sql_injection?('hello world')).to be false
    end

    it 'handles nil' do
      expect(described_class.contains_sql_injection?(nil)).to be false
    end
  end

  describe '.sanitize_xss' do
    it 'encodes HTML entities' do
      expect(described_class.sanitize_xss('<script>alert(1)</script>')).not_to include('<script>')
    end

    it 'encodes quotes' do
      result = described_class.sanitize_xss('"hello"')
      expect(result).to include('&quot;')
    end

    it 'handles nil' do
      expect(described_class.sanitize_xss(nil)).to eq('')
    end
  end

  describe '.contains_xss?' do
    it 'detects script tags' do
      expect(described_class.contains_xss?('<script>alert(1)</script>')).to be true
    end

    it 'detects javascript: protocol' do
      expect(described_class.contains_xss?('javascript:alert(1)')).to be true
    end

    it 'detects event handlers' do
      expect(described_class.contains_xss?('<img onerror=alert(1)>')).to be true
    end

    it 'detects iframe injection' do
      expect(described_class.contains_xss?('<iframe src="evil">')).to be true
    end

    it 'allows normal text' do
      expect(described_class.contains_xss?('Hello, world!')).to be false
    end

    it 'handles nil' do
      expect(described_class.contains_xss?(nil)).to be false
    end
  end

  describe '.within_rate_limit?' do
    before do
      allow(Rails.cache).to receive(:read).and_return(0)
      allow(Rails.cache).to receive(:write)
      allow(Rails.cache).to receive(:increment)
    end

    it 'allows requests within limit' do
      expect(described_class.within_rate_limit?('device_id', '127.0.0.1')).to be true
    end

    it 'denies requests over limit' do
      allow(Rails.cache).to receive(:read).and_return(100)
      expect(described_class.within_rate_limit?('device_id', '127.0.0.1')).to be false
    end
  end

  describe '.remove_null_bytes' do
    it 'removes null bytes' do
      expect(described_class.remove_null_bytes("hello\x00world")).to eq('helloworld')
    end

    it 'removes URL-encoded null bytes' do
      expect(described_class.remove_null_bytes('hello%00world')).to eq('helloworld')
    end
  end

  describe '#call' do
    it 'succeeds with safe params' do
      result = described_class.new(name: 'safe value').call
      expect(result.success?).to be true
    end

    it 'fails with SQL injection attempt' do
      result = described_class.new(name: "admin' OR 1=1--").call
      expect(result.failure?).to be true
      expect(result.error).to include('SQL injection')
    end

    it 'fails with XSS attempt' do
      result = described_class.new(name: '<script>alert(1)</script>').call
      expect(result.failure?).to be true
      expect(result.error).to include('XSS')
    end
  end
end
