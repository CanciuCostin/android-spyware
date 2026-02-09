# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PhoneNumberValidator do
  describe '.validate' do
    context 'with valid phone numbers' do
      it 'accepts international format' do
        result = described_class.validate('+1-555-123-4567')
        expect(result.valid?).to be true
      end

      it 'accepts digits only' do
        result = described_class.validate('5551234567')
        expect(result.valid?).to be true
      end

      it 'accepts with parentheses' do
        result = described_class.validate('(555) 123-4567')
        expect(result.valid?).to be true
      end

      it 'accepts with spaces' do
        result = described_class.validate('+44 20 7946 0958')
        expect(result.valid?).to be true
      end

      it 'accepts short numbers (3+ digits)' do
        result = described_class.validate('911')
        expect(result.valid?).to be true
      end
    end

    context 'with invalid phone numbers' do
      it 'rejects nil' do
        result = described_class.validate(nil)
        expect(result.valid?).to be false
        expect(result.error).to include('required')
      end

      it 'rejects empty string' do
        result = described_class.validate('')
        expect(result.valid?).to be false
      end

      it 'rejects too-short numbers' do
        result = described_class.validate('12')
        expect(result.valid?).to be false
        expect(result.error).to include('short')
      end

      it 'rejects numbers with letters' do
        result = described_class.validate('+1-555-CALL-ME')
        expect(result.valid?).to be false
      end

      it 'rejects injection attempts' do
        result = described_class.validate("555; rm -rf /")
        expect(result.valid?).to be false
      end
    end
  end

  describe '.sanitize' do
    it 'removes invalid characters' do
      expect(described_class.sanitize('abc+1-555def')).to eq('+1-555')
    end

    it 'preserves digits and formatting' do
      expect(described_class.sanitize('+1 (555) 123-4567')).to eq('+1 (555) 123-4567')
    end

    it 'truncates to max length' do
      long_number = '+1' + '5' * 25
      result = described_class.sanitize(long_number)
      expect(result.length).to be <= 20
    end
  end
end
