# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommandValidator do
  describe '.validate' do
    context 'with valid commands' do
      %w[get_contacts take_picture start_camera dump_sms].each do |cmd|
        it "accepts '#{cmd}'" do
          result = described_class.validate(cmd)
          expect(result.valid?).to be true
          expect(result.value).to eq(cmd)
        end
      end
    end

    context 'with invalid commands' do
      it 'rejects empty command' do
        result = described_class.validate('')
        expect(result.valid?).to be false
        expect(result.error).to include('required')
      end

      it 'rejects nil command' do
        result = described_class.validate(nil)
        expect(result.valid?).to be false
      end

      it 'rejects unlisted commands' do
        result = described_class.validate('execute_shell')
        expect(result.valid?).to be false
        expect(result.error).to include('not allowed')
      end

      it 'rejects commands with injection attempts' do
        result = described_class.validate('get_contacts; rm -rf /')
        expect(result.valid?).to be false
      end
    end

    context 'with parameter validation' do
      it 'validates required params for send_sms' do
        result = described_class.validate('send_sms', {})
        expect(result.valid?).to be false
        expect(result.error).to include('phone_number')
        expect(result.error).to include('message_body')
      end

      it 'accepts send_sms with required params' do
        result = described_class.validate('send_sms', phone_number: '+123', message_body: 'hi')
        expect(result.valid?).to be true
      end

      it 'validates set_audio_mode values' do
        result = described_class.validate('set_audio_mode', mode: 'invalid')
        expect(result.valid?).to be false
        expect(result.error).to include('audio mode')
      end

      it 'accepts valid audio modes' do
        %w[normal vibrate silent].each do |mode|
          result = described_class.validate('set_audio_mode', mode: mode)
          expect(result.valid?).to be true
        end
      end

      it 'accepts commands without required params defined' do
        result = described_class.validate('get_contacts')
        expect(result.valid?).to be true
      end
    end
  end

  describe '.allowed?' do
    it 'returns true for allowed commands' do
      expect(described_class.allowed?('get_contacts')).to be true
    end

    it 'returns false for disallowed commands' do
      expect(described_class.allowed?('hack_system')).to be false
    end
  end
end
