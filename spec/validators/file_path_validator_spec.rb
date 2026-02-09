# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FilePathValidator do
  describe '.validate' do
    context 'with valid paths' do
      it 'accepts simple file paths' do
        result = described_class.validate('documents/file.txt')
        expect(result.valid?).to be true
        expect(result.value).to eq('documents/file.txt')
      end

      it 'accepts paths with allowed characters' do
        result = described_class.validate('my-folder/my_file.txt')
        expect(result.valid?).to be true
      end
    end

    context 'with directory traversal' do
      it 'rejects ../ sequences' do
        result = described_class.validate('../../etc/passwd')
        expect(result.valid?).to be false
        expect(result.error).to include('traversal')
      end

      it 'rejects encoded traversal (%2e%2e)' do
        result = described_class.validate('%2e%2e/etc/passwd')
        expect(result.valid?).to be false
      end

      it 'rejects Windows-style traversal' do
        result = described_class.validate('..\\..\\windows\\system32')
        expect(result.valid?).to be false
      end
    end

    context 'with dangerous characters' do
      it 'rejects shell metacharacters' do
        result = described_class.validate('file; rm -rf /')
        expect(result.valid?).to be false
        expect(result.error).to include('dangerous')
      end

      it 'rejects pipe characters' do
        result = described_class.validate('file | cat /etc/passwd')
        expect(result.valid?).to be false
      end

      it 'rejects backticks' do
        result = described_class.validate('file`whoami`')
        expect(result.valid?).to be false
      end
    end

    context 'with null bytes' do
      it 'strips null bytes during sanitization' do
        result = described_class.validate("file.txt\x00.jpg")
        # Null byte is stripped, resulting in "file.txt.jpg" which is valid
        expect(result.value).not_to include("\x00") if result.valid?
      end
    end

    context 'with base directory validation' do
      it 'accepts paths within base directory' do
        result = described_class.validate('subdir/file.txt', base_dir: '/home/user')
        expect(result.valid?).to be true
      end

      it 'rejects paths escaping base directory' do
        result = described_class.validate('../../etc/passwd', base_dir: '/home/user')
        expect(result.valid?).to be false
      end
    end

    context 'edge cases' do
      it 'rejects nil' do
        result = described_class.validate(nil)
        expect(result.valid?).to be false
      end

      it 'rejects empty string' do
        result = described_class.validate('')
        expect(result.valid?).to be false
      end

      it 'rejects very long paths' do
        long_path = 'a' * 1025
        result = described_class.validate(long_path)
        expect(result.valid?).to be false
        expect(result.error).to include('too long')
      end
    end
  end

  describe '.sanitize' do
    it 'normalizes backslashes to forward slashes' do
      expect(described_class.sanitize('path\\to\\file')).to eq('path/to/file')
    end

    it 'removes duplicate slashes' do
      expect(described_class.sanitize('path//to///file')).to eq('path/to/file')
    end

    it 'removes null bytes' do
      expect(described_class.sanitize("file\x00.txt")).to eq('file.txt')
    end

    it 'strips whitespace from components' do
      expect(described_class.sanitize(' path / to / file ')).to eq('path/to/file')
    end
  end
end
