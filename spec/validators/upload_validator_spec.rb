# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UploadValidator do
  let(:valid_uuid) { 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' }

  describe '.validate' do
    let(:valid_params) do
      {
        upload_id: valid_uuid,
        filename: 'test.apk',
        total_chunks: 10,
        chunk_index: 0
      }
    end

    context 'with valid params' do
      it 'succeeds' do
        result = described_class.validate(valid_params)
        expect(result.valid?).to be true
      end
    end

    context 'with invalid upload_id' do
      it 'rejects non-UUID upload_id' do
        result = described_class.validate(valid_params.merge(upload_id: 'not-uuid'))
        expect(result.valid?).to be false
        expect(result.error).to include('Upload ID')
      end
    end

    context 'with invalid filename' do
      it 'rejects empty filename' do
        result = described_class.validate(valid_params.merge(filename: ''))
        expect(result.valid?).to be false
      end

      it 'rejects filename with path separators' do
        result = described_class.validate(valid_params.merge(filename: '../evil.txt'))
        expect(result.valid?).to be false
      end

      it 'rejects dangerous extensions' do
        result = described_class.validate(valid_params.merge(filename: 'evil.exe'))
        expect(result.valid?).to be false
        expect(result.error).to include('Dangerous')
      end

      it 'rejects filename with null bytes' do
        result = described_class.validate(valid_params.merge(filename: "test\x00.txt"))
        expect(result.valid?).to be false
      end
    end

    context 'with invalid chunks' do
      it 'rejects zero total chunks' do
        result = described_class.validate(valid_params.merge(total_chunks: 0))
        expect(result.valid?).to be false
      end

      it 'rejects too many chunks' do
        result = described_class.validate(valid_params.merge(total_chunks: 10_001))
        expect(result.valid?).to be false
      end

      it 'rejects negative chunk index' do
        result = described_class.validate(valid_params.merge(chunk_index: -1))
        expect(result.valid?).to be false
      end

      it 'rejects chunk index >= total_chunks' do
        result = described_class.validate(valid_params.merge(chunk_index: 10, total_chunks: 10))
        expect(result.valid?).to be false
      end
    end

    context 'with invalid content type' do
      it 'rejects unknown content types' do
        result = described_class.validate(valid_params.merge(content_type: 'application/x-evil'))
        expect(result.valid?).to be false
      end

      it 'accepts known content types' do
        result = described_class.validate(valid_params.merge(content_type: 'image/jpeg'))
        expect(result.valid?).to be true
      end
    end
  end

  describe '.validate_upload_id' do
    it 'accepts valid UUIDs' do
      result = described_class.validate_upload_id(valid_uuid)
      expect(result.valid?).to be true
    end

    it 'rejects nil' do
      result = described_class.validate_upload_id(nil)
      expect(result.valid?).to be false
    end

    it 'rejects non-UUID strings' do
      result = described_class.validate_upload_id('not-a-proper-uuid')
      expect(result.valid?).to be false
    end
  end
end
