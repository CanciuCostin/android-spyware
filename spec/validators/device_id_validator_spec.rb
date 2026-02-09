# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeviceIdValidator do
  describe '.validate' do
    context 'with valid device IDs' do
      it 'accepts alphanumeric IDs' do
        result = described_class.validate('device123')
        expect(result.valid?).to be true
        expect(result.value).to eq('device123')
      end

      it 'accepts UUIDs' do
        uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
        result = described_class.validate(uuid)
        expect(result.valid?).to be true
      end

      it 'accepts hex strings' do
        result = described_class.validate('abcdef123456')
        expect(result.valid?).to be true
      end

      it 'accepts IDs with dots, colons, underscores, dashes' do
        result = described_class.validate('device_1.0:abc-def')
        expect(result.valid?).to be true
      end

      it 'strips whitespace' do
        result = described_class.validate('  device123  ')
        expect(result.valid?).to be true
        expect(result.value).to eq('device123')
      end
    end

    context 'with invalid device IDs' do
      it 'rejects nil' do
        result = described_class.validate(nil)
        expect(result.valid?).to be false
        expect(result.error).to include('required')
      end

      it 'rejects empty string' do
        result = described_class.validate('')
        expect(result.valid?).to be false
      end

      it 'rejects whitespace-only string' do
        result = described_class.validate('   ')
        expect(result.valid?).to be false
      end

      it 'rejects IDs with shell metacharacters' do
        result = described_class.validate('device; rm -rf /')
        expect(result.valid?).to be false
        expect(result.error).to include('invalid characters')
      end

      it 'rejects IDs with SQL injection attempts' do
        result = described_class.validate("device' OR '1'='1")
        expect(result.valid?).to be false
      end

      it 'rejects IDs exceeding max length' do
        long_id = 'a' * 129
        result = described_class.validate(long_id)
        expect(result.valid?).to be false
        expect(result.error).to include('too long')
      end

      it 'rejects IDs with unicode tricks' do
        result = described_class.validate("device\u200Bid")
        expect(result.valid?).to be false
      end
    end
  end

  describe '.uuid?' do
    it 'returns true for valid UUIDs' do
      expect(described_class.uuid?('a1b2c3d4-e5f6-7890-abcd-ef1234567890')).to be true
    end

    it 'returns false for non-UUIDs' do
      expect(described_class.uuid?('not-a-uuid')).to be false
    end
  end

  describe '.hex?' do
    it 'returns true for hex strings' do
      expect(described_class.hex?('abcdef123456')).to be true
    end

    it 'returns false for non-hex strings' do
      expect(described_class.hex?('xyz123')).to be false
    end
  end

  describe '.sanitize' do
    it 'returns sanitized ID for valid input' do
      expect(described_class.sanitize('device-123')).to eq('device-123')
    end

    it 'returns nil for invalid input' do
      expect(described_class.sanitize('device; evil')).to be_nil
    end
  end
end
