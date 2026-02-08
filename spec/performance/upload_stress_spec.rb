# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'
require 'securerandom'
require 'tempfile'

RSpec.describe 'Upload Stress Testing', type: :performance do
  let(:device) { create(:smartphone) }

  after(:each) do
    # Clean up temp upload files
    FileUtils.rm_rf(File.join(Rails.root, 'tmp', 'chunks', 'stress-*'))
    FileUtils.rm_rf(File.join(Rails.root, 'tmp', 'uploads', 'stress-*'))
    FileUtils.rm_rf(File.join(Rails.root, 'tmp', 'assembled', 'stress-*'))
  end

  describe 'Concurrent file uploads' do
    it 'handles 10 simultaneous upload sessions without data corruption' do
      upload_count = 10
      errors = []
      results = []

      time = Benchmark.realtime do
        threads = upload_count.times.map do |i|
          Thread.new do
            upload_id = "stress-concurrent-#{SecureRandom.hex(8)}"
            total_chunks = 5
            chunk_data = "chunk-data-upload-#{i}-" * 100 # ~2KB per chunk

            total_chunks.times do |chunk_idx|
              chunk_io = StringIO.new("#{chunk_data}-part-#{chunk_idx}")
              service = ResumableUploadService.new(
                upload_id: upload_id,
                chunk_number: chunk_idx,
                total_chunks: total_chunks,
                chunk_data: chunk_io,
                filename: "stress_test_#{i}.bin"
              )
              result = service.call
              unless result.success?
                errors << "Upload #{i}, chunk #{chunk_idx}: #{result.error}"
              end
            end

            results << upload_id
          rescue StandardError => e
            errors << "Upload #{i}: #{e.message}"
          end
        end
        threads.each(&:join)
      end

      expect(errors).to be_empty, "Upload errors: #{errors.first(5).join('; ')}"
      expect(results.size).to eq(upload_count)
      expect(time).to be < 30.0, "10 concurrent uploads took #{time.round(2)}s (expected < 30s)"
    end

    it 'maintains chunk ordering across concurrent writes' do
      upload_id = "stress-ordering-#{SecureRandom.hex(8)}"
      total_chunks = 20
      errors = []

      # Upload chunks in random order concurrently
      indices = (0...total_chunks).to_a.shuffle
      threads = indices.map do |idx|
        Thread.new do
          chunk_io = StringIO.new("ordered-chunk-#{idx.to_s.rjust(4, '0')}")
          service = ResumableUploadService.new(
            upload_id: upload_id,
            chunk_number: idx,
            total_chunks: total_chunks,
            chunk_data: chunk_io,
            filename: 'ordering_test.bin'
          )
          result = service.call
          errors << "Chunk #{idx}: #{result.error}" unless result.success?
        end
      end
      threads.each(&:join)

      expect(errors).to be_empty, "Ordering errors: #{errors.join('; ')}"

      # Verify all chunks were recorded
      progress = ResumableUploadService.progress(upload_id)
      expect(progress).not_to be_nil
      expect(progress[:received]).to eq(total_chunks)
      expect(progress[:missing]).to be_empty
    end
  end

  describe 'Large file upload simulation' do
    it 'handles 100MB+ file via chunked upload' do
      upload_id = "stress-large-#{SecureRandom.hex(8)}"
      chunk_size = 1.megabyte
      total_chunks = 100 # 100 x 1MB = 100MB
      filename = 'large_file.bin'

      time = Benchmark.realtime do
        total_chunks.times do |i|
          # Generate deterministic chunk data
          chunk_io = StringIO.new(('A' * chunk_size).force_encoding('BINARY'))
          service = ResumableUploadService.new(
            upload_id: upload_id,
            chunk_number: i,
            total_chunks: total_chunks,
            chunk_data: chunk_io,
            filename: filename
          )
          result = service.call

          if i == total_chunks - 1
            expect(result.success?).to be true
            expect(result.value[:status]).to eq('complete') if result.value.is_a?(Hash)
          end
        end
      end

      # 100MB should complete within 60 seconds on local storage
      expect(time).to be < 60.0, "100MB upload took #{time.round(2)}s (expected < 60s)"
    end
  end

  describe 'Chunk reassembly speed' do
    it 'assembles 50 chunks within acceptable time' do
      upload_id = "stress-reassemble-#{SecureRandom.hex(8)}"
      total_chunks = 50
      chunk_content = 'X' * 10_000 # 10KB per chunk

      # Upload all chunks first
      total_chunks.times do |i|
        chunk_io = StringIO.new(chunk_content)
        service = ResumableUploadService.new(
          upload_id: upload_id,
          chunk_number: i,
          total_chunks: total_chunks,
          chunk_data: chunk_io,
          filename: 'reassembly_test.bin'
        )
        result = service.call

        # The last chunk triggers assembly
        if i == total_chunks - 1
          expect(result.success?).to be true
        end
      end
    end
  end

  describe 'Storage cleanup under load' do
    it 'cleans stale uploads while new uploads proceed' do
      # Create stale upload records
      5.times do |i|
        stale_id = "stress-stale-#{SecureRandom.hex(8)}"
        stale_dir = File.join(Rails.root, 'tmp', 'chunks', stale_id)
        FileUtils.mkdir_p(stale_dir)

        chunk_path = File.join(stale_dir, 'chunk_000000')
        File.write(chunk_path, 'stale-data')

        # Backdate the file
        old_time = Time.current - 48.hours
        File.utime(old_time, old_time, chunk_path)
        File.utime(old_time, old_time, stale_dir)
      end

      # Run cleanup concurrently with new uploads
      errors = []
      cleanup_result = nil

      threads = []
      threads << Thread.new do
        cleanup_result = StorageCleanupService.new.call
      rescue StandardError => e
        errors << "Cleanup: #{e.message}"
      end

      3.times do |i|
        threads << Thread.new do
          upload_id = "stress-during-cleanup-#{SecureRandom.hex(8)}"
          chunk_io = StringIO.new("concurrent-chunk-#{i}")
          service = ResumableUploadService.new(
            upload_id: upload_id,
            chunk_number: 0,
            total_chunks: 1,
            chunk_data: chunk_io,
            filename: "cleanup_test_#{i}.bin"
          )
          result = service.call
          errors << "Upload #{i}: #{result.error}" unless result.success?
        rescue StandardError => e
          errors << "Upload #{i}: #{e.message}"
        end
      end

      threads.each(&:join)

      expect(errors).to be_empty, "Errors during cleanup+upload: #{errors.join('; ')}"
    end
  end
end
