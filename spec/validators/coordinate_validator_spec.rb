# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoordinateValidator do
  describe '.validate' do
    context 'with valid coordinates' do
      it 'accepts typical lat/lng' do
        result = described_class.validate(42.3601, -71.0589)
        expect(result.valid?).to be true
        expect(result.value).to eq(latitude: 42.3601, longitude: -71.0589)
      end

      it 'accepts boundary values' do
        expect(described_class.validate(90.0, 180.0).valid?).to be true
        expect(described_class.validate(-90.0, -180.0).valid?).to be true
        expect(described_class.validate(0.0, 0.0).valid?).to be true
      end

      it 'accepts string coordinates' do
        result = described_class.validate('42.3601', '-71.0589')
        expect(result.valid?).to be true
      end

      it 'accepts integer coordinates' do
        result = described_class.validate(42, -71)
        expect(result.valid?).to be true
      end
    end

    context 'with invalid coordinates' do
      it 'rejects latitude > 90' do
        result = described_class.validate(91.0, 0.0)
        expect(result.valid?).to be false
        expect(result.error).to include('Latitude')
      end

      it 'rejects latitude < -90' do
        result = described_class.validate(-91.0, 0.0)
        expect(result.valid?).to be false
      end

      it 'rejects longitude > 180' do
        result = described_class.validate(0.0, 181.0)
        expect(result.valid?).to be false
        expect(result.error).to include('Longitude')
      end

      it 'rejects longitude < -180' do
        result = described_class.validate(0.0, -181.0)
        expect(result.valid?).to be false
      end

      it 'rejects nil latitude' do
        result = described_class.validate(nil, 0.0)
        expect(result.valid?).to be false
      end

      it 'rejects nil longitude' do
        result = described_class.validate(0.0, nil)
        expect(result.valid?).to be false
      end

      it 'rejects non-numeric strings' do
        result = described_class.validate('abc', '0.0')
        expect(result.valid?).to be false
        expect(result.error).to include('number')
      end
    end
  end

  describe '.validate_latitude' do
    it 'accepts valid latitude' do
      result = described_class.validate_latitude(45.0)
      expect(result.valid?).to be true
      expect(result.value).to eq(45.0)
    end

    it 'rejects out-of-range latitude' do
      expect(described_class.validate_latitude(91.0).valid?).to be false
      expect(described_class.validate_latitude(-91.0).valid?).to be false
    end
  end

  describe '.validate_longitude' do
    it 'accepts valid longitude' do
      result = described_class.validate_longitude(-73.5)
      expect(result.valid?).to be true
      expect(result.value).to eq(-73.5)
    end

    it 'rejects out-of-range longitude' do
      expect(described_class.validate_longitude(181.0).valid?).to be false
      expect(described_class.validate_longitude(-181.0).valid?).to be false
    end
  end
end
