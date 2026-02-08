# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'File Upload Flow', type: :integration do
  let(:device_id) { 'test-device-upload-001' }
  let!(:smartphone) { create_test_device(device_id: device_id) }
  let(:upload_id) { 'a1b2c3d4-e5f6-7890-abcd-ef1234567890' }
  let(:upload_dir) { File.join(Rails.root, 'tmp', 'uploads') }
  let(:dest_dir) { File.join(Rails.root, 'files', 'uploads') }

  before do
    FileUtils.mkdir_p(upload_dir)
  end

  after do
    # Clean up test upload files
    FileUtils.rm_rf(File.join(upload_dir, upload_id))
    FileUtils.rm_f(File.join(upload_dir, "#{upload_id}.meta"))
    FileUtils.rm_rf(File.join(dest_dir, 'test_file.txt'))
  end

  describe 'full chunked upload flow (init → chunks → finalize)' do
    it 'uploads a file in three chunks and finalizes successfully' do
      chunk_content_1 = 'chunk-data-part-1-'
      chunk_content_2 = 'chunk-data-part-2-'
      chunk_content_3 = 'chunk-data-part-3'

      # Upload chunk 0
      result1 = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '3',
        file: string_io_upload(chunk_content_1),
        filename: 'test_file.txt'
      )
      expect(result1.success?).to be true
      expect(result1.value[:chunk_index]).to eq(0)

      # Upload chunk 1
      result2 = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '1',
        total_chunks: '3',
        file: string_io_upload(chunk_content_2),
        filename: 'test_file.txt'
      )
      expect(result2.success?).to be true

      # Upload chunk 2
      result3 = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '2',
        total_chunks: '3',
        file: string_io_upload(chunk_content_3),
        filename: 'test_file.txt'
      )
      expect(result3.success?).to be true
      expect(result3.value[:progress]).to eq(100.0)

      # Finalize
      finalize_result = FileFinalizationService.call(upload_id, 'test_file.txt')
      expect(finalize_result.success?).to be true
      expect(finalize_result.value[:filename]).to eq('test_file.txt')

      # Verify file exists and has correct content
      final_path = finalize_result.value[:path]
      expect(File.exist?(final_path)).to be true
      content = File.read(final_path)
      expect(content).to eq("#{chunk_content_1}#{chunk_content_2}#{chunk_content_3}")

      # Cleanup
      FileUtils.rm_f(final_path) if File.exist?(final_path)
    end
  end

  describe 'resume interrupted upload' do
    it 'allows uploading remaining chunks after interruption' do
      # Upload chunk 0 only
      FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '2',
        file: string_io_upload('first-part-'),
        filename: 'resume_test.txt'
      )

      # Verify metadata shows partial upload
      metadata_path = File.join(upload_dir, "#{upload_id}.meta")
      metadata = JSON.parse(File.read(metadata_path))
      expect(metadata['chunks_received']).to eq([0])

      # "Resume" by uploading chunk 1
      result = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '1',
        total_chunks: '2',
        file: string_io_upload('second-part'),
        filename: 'resume_test.txt'
      )
      expect(result.success?).to be true
      expect(result.value[:progress]).to eq(100.0)
    end
  end

  describe 'concurrent uploads from same device' do
    let(:upload_id_2) { 'b2c3d4e5-f6a7-8901-bcde-f12345678901' }

    after do
      FileUtils.rm_rf(File.join(upload_dir, upload_id_2))
      FileUtils.rm_f(File.join(upload_dir, "#{upload_id_2}.meta"))
    end

    it 'handles two simultaneous uploads independently' do
      # Upload 1, chunk 0
      r1 = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '1',
        file: string_io_upload('file-one-content'),
        filename: 'file1.txt'
      )

      # Upload 2, chunk 0
      r2 = FileUploadService.call(
        smartphone,
        upload_id: upload_id_2,
        chunk_index: '0',
        total_chunks: '1',
        file: string_io_upload('file-two-content'),
        filename: 'file2.txt'
      )

      expect(r1.success?).to be true
      expect(r2.success?).to be true

      # Both upload files exist separately
      expect(File.exist?(File.join(upload_dir, upload_id))).to be true
      expect(File.exist?(File.join(upload_dir, upload_id_2))).to be true
    end
  end

  describe 'large file handling' do
    it 'rejects chunks exceeding MAX_CHUNK_SIZE' do
      oversized_content = 'x' * (11 * 1024 * 1024) # 11MB > 10MB max

      result = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '1',
        file: string_io_upload(oversized_content),
        filename: 'too_big.txt'
      )

      expect(result.failure?).to be true
      expect(result.error).to include('Chunk too large')
    end

    it 'rejects uploads with too many chunks' do
      result = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '20000',
        file: string_io_upload('data'),
        filename: 'many_chunks.txt'
      )

      expect(result.failure?).to be true
      expect(result.error).to include('Too many chunks')
    end
  end

  describe 'invalid chunk handling' do
    it 'rejects chunk with invalid upload_id format' do
      result = FileUploadService.call(
        smartphone,
        upload_id: 'invalid-id!!',
        chunk_index: '0',
        total_chunks: '1',
        file: string_io_upload('data'),
        filename: 'test.txt'
      )

      expect(result.failure?).to be true
      expect(result.error).to include('Invalid upload_id')
    end

    it 'rejects negative chunk index' do
      result = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '-1',
        total_chunks: '2',
        file: string_io_upload('data'),
        filename: 'test.txt'
      )

      expect(result.failure?).to be true
      expect(result.error).to include('Invalid chunk index')
    end

    it 'rejects chunk index exceeding total_chunks' do
      result = FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '5',
        total_chunks: '3',
        file: string_io_upload('data'),
        filename: 'test.txt'
      )

      expect(result.failure?).to be true
      expect(result.error).to include('Invalid chunk index')
    end

    it 'rejects finalization with missing chunks' do
      FileUploadService.call(
        smartphone,
        upload_id: upload_id,
        chunk_index: '0',
        total_chunks: '3',
        file: string_io_upload('partial'),
        filename: 'incomplete.txt'
      )

      result = FileFinalizationService.call(upload_id, 'incomplete.txt')
      expect(result.failure?).to be true
      expect(result.error).to include('Missing chunks')
    end

    it 'rejects finalization for non-existent upload' do
      result = FileFinalizationService.call('nonexistent-upload-id', 'ghost.txt')

      expect(result.failure?).to be true
      expect(result.error).to include('Upload not found')
    end
  end

  private

  def string_io_upload(content)
    io = StringIO.new(content)
    allow(io).to receive(:size).and_return(content.bytesize)
    allow(io).to receive(:original_filename).and_return('test.txt')
    io
  end
end
